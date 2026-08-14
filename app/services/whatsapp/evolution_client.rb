require "net/http"
require "json"

module WhatsApp
  class EvolutionClient
    DEFAULT_BASE_URL = "http://evolution-api:8080"
    DEFAULT_INSTANCE_NAME = "dog-grooming-main"

    attr_reader :base_url, :api_key, :instance_name

    def initialize(
      base_url: ENV.fetch("EVOLUTION_API_BASE_URL", DEFAULT_BASE_URL),
      api_key: ENV["EVOLUTION_API_KEY"],
      instance_name: ENV.fetch("EVOLUTION_INSTANCE_NAME", DEFAULT_INSTANCE_NAME)
    )
      @base_url = base_url.to_s.chomp("/")
      @api_key = api_key.to_s
      @instance_name = instance_name.to_s.presence || DEFAULT_INSTANCE_NAME
    end

    def configured?
      base_url.present? && api_key.present?
    end

    def provider
      ENV.fetch("WHATSAPP_PROVIDER", "disabled")
    end

    def setup_instance
      response = post("/instance/create", setup_payload)
      if instance_name_in_use?(response)
        return recreate_instance if disconnected_instance_without_number?
        return set_webhook
      end

      response
    end

    def fetch_instances
      get("/instance/fetchInstances")
    end

    def connection_state
      get("/instance/connectionState/#{escaped_instance_name}")
    end

    def set_webhook
      return response_hash(success: false, status: nil, error: "Evolution webhook no está configurado.") if webhook_payload.blank?

      post("/webhook/set/#{escaped_instance_name}", webhook: webhook_payload.merge(enabled: true))
    end

    def connect_instance(number: nil)
      query = number.present? ? "?number=#{ERB::Util.url_encode(PhoneNormalizer.normalize(number))}" : ""
      response = get("/instance/connect/#{escaped_instance_name}#{query}")
      return post("/instance/create", setup_payload) if number.blank? && missing_instance?(response)
      return recreate_instance if number.blank? && empty_qr_response?(response) && disconnected_instance_without_number?

      response
    end

    def send_text(number:, text:, delay: 1_200, link_preview: false)
      post(
        "/message/sendText/#{escaped_instance_name}",
        {
          number: PhoneNormalizer.normalize(number),
          text: text.to_s,
          delay: delay,
          linkPreview: link_preview
        }.compact
      )
    end

    def send_presence(number:, presence: "composing", delay: 1_200)
      post(
        "/chat/sendPresence/#{escaped_instance_name}",
        {
          number: PhoneNormalizer.normalize(number),
          presence: presence,
          delay: delay
        }.compact
      )
    end

    private
      def setup_payload
        {
          instanceName: instance_name,
          integration: "WHATSAPP-BAILEYS",
          qrcode: true,
          rejectCall: true,
          msgCall: "Dog Grooming no recibe llamadas por este canal.",
          groupsIgnore: true,
          alwaysOnline: false,
          readMessages: false,
          readStatus: false,
          syncFullHistory: false,
          webhook: webhook_payload
        }.compact
      end

      def webhook_payload
        return nil if ENV["EVOLUTION_WEBHOOK_SECRET"].blank?

        {
          url: Rails.application.routes.url_helpers.webhooks_evolution_whatsapp_url(
            host: app_host,
            protocol: app_protocol
          ),
          byEvents: true,
          base64: false,
          headers: {
            Authorization: "Bearer #{ENV.fetch("EVOLUTION_WEBHOOK_SECRET")}"
          },
          events: %w[
            CONNECTION_UPDATE
            MESSAGES_UPSERT
          ]
        }
      end

      def get(path)
        request(Net::HTTP::Get.new(uri_for(path)))
      end

      def post(path, body)
        request(Net::HTTP::Post.new(uri_for(path)), body: body)
      end

      def delete(path)
        request(Net::HTTP::Delete.new(uri_for(path)))
      end

      def delete_instance
        delete("/instance/delete/#{escaped_instance_name}")
      end

      def recreate_instance
        delete_response = delete_instance
        return delete_response unless delete_response[:success] || missing_instance?(delete_response)

        post("/instance/create", setup_payload)
      end

      def request(http_request, body: nil)
        return response_hash(success: false, status: nil, error: "Evolution API no está configurada.") unless configured?

        http_request["apikey"] = api_key
        http_request["Content-Type"] = "application/json"
        http_request.body = JSON.generate(body) if body.present?

        response = Net::HTTP.start(http_request.uri.hostname, http_request.uri.port, use_ssl: http_request.uri.scheme == "https") do |http|
          http.request(http_request)
        end

        response_hash(
          success: response.is_a?(Net::HTTPSuccess),
          status: response.code.to_i,
          body: parse_body(response.body)
        )
      rescue StandardError => error
        response_hash(success: false, status: nil, error: "#{error.class}: #{error.message}")
      end

      def response_hash(success:, status:, body: {}, error: nil)
        raw_body = body.presence || {}
        {
          success: success,
          status: status,
          body: raw_body,
          sanitized_body: WhatsApp::PayloadSanitizer.call(raw_body),
          error: error
        }.compact
      end

      def parse_body(body)
        return {} if body.blank?

        JSON.parse(body)
      rescue JSON::ParserError
        { "raw" => body.to_s.first(1_000) }
      end

      def uri_for(path)
        URI.parse("#{base_url}#{path}")
      end

      def instance_name_in_use?(response)
        return false unless response[:status].to_i == 403

        messages = Array(response.dig(:body, "response", "message")) + Array(response.dig(:sanitized_body, "response", "message"))
        messages.any? { |message| message.to_s.include?("already in use") || message.to_s.include?("is already in use") }
      end

      def missing_instance?(response)
        return false unless response[:status].to_i == 404

        messages = Array(response.dig(:body, "response", "message")) + Array(response.dig(:sanitized_body, "response", "message"))
        messages.any? { |message| message.to_s.include?("does not exist") || message.to_s.include?("not found") }
      end

      def disconnected_instance_without_number?
        instance = current_instance_payload
        return false if instance.blank?
        return false if instance_number_present?(instance)

        status_response = connection_state
        states = [
          status_response.dig(:body, "instance", "state"),
          status_response.dig(:sanitized_body, "instance", "state"),
          instance["connectionStatus"]
        ].compact.map { |state| state.to_s.downcase }

        (states & %w[close closed disconnected connecting]).any?
      end

      def current_instance_payload
        payloads = collect_instance_payloads(fetch_instances[:body])
        payloads.find { |payload| instance_name_for(payload) == instance_name } || payloads.first
      end

      def collect_instance_payloads(value)
        case value
        when Array
          value.flat_map { |entry| collect_instance_payloads(entry) }
        when Hash
          if instance_payload?(value)
            [ value ]
          else
            [
              value["instance"],
              value["instances"],
              value["data"],
              value.dig("response", "instances")
            ].compact.flat_map { |entry| collect_instance_payloads(entry) }
          end
        else
          []
        end
      end

      def instance_payload?(payload)
        payload["name"].present? ||
          payload["instanceName"].present? ||
          payload["ownerJid"].present? ||
          payload["number"].present?
      end

      def instance_name_for(payload)
        payload["name"].presence ||
          payload["instanceName"].presence ||
          payload.dig("instance", "instanceName").presence
      end

      def instance_number_present?(payload)
        [
          payload["number"],
          payload["phone"],
          payload["phoneNumber"],
          payload["displayPhoneNumber"],
          payload["ownerJid"],
          payload["jid"],
          payload.dig("owner", "jid"),
          payload.dig("profile", "id"),
          payload.dig("instance", "ownerJid")
        ].compact_blank.any?
      end

      def empty_qr_response?(response)
        return false unless response[:success]

        body = response[:body]
        return false unless body.is_a?(Hash)

        qr_values = [
          body["base64"],
          body.dig("qrcode", "base64"),
          body.dig("data", "base64"),
          body["pairingCode"],
          body.dig("qrcode", "pairingCode"),
          body.dig("data", "pairingCode"),
          body["code"],
          body.dig("qrcode", "code"),
          body.dig("data", "code")
        ].compact_blank

        qr_values.blank? && body["count"].to_i.zero?
      end

      def escaped_instance_name
        ERB::Util.url_encode(instance_name)
      end

      def app_host
        AppUrl.host
      end

      def app_protocol
        AppUrl.protocol
      end
  end
end
