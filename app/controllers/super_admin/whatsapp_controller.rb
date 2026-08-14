module SuperAdmin
  class WhatsAppController < BaseController
    before_action :set_client

    def show
      load_dashboard
    end

    def setup_evolution
      @setup_response = @client.setup_instance
      load_dashboard
      render :show, status: @setup_response[:success] ? :ok : :bad_gateway
    end

    def refresh_status
      @status_response = @client.connection_state
      load_dashboard
      render :show, status: @status_response[:success] ? :ok : :bad_gateway
    end

    def connect
      @connect_response = @client.connect_instance(number: params[:number])
      load_dashboard
      render :show, status: @connect_response[:success] ? :ok : :bad_gateway
    end

    private
      def set_client
        @client = WhatsApp::EvolutionClient.new
      end

      def load_dashboard
        @dashboard = SuperAdmin::Dashboard.new(params: ActionController::Parameters.new)
        @provider = ENV.fetch("WHATSAPP_PROVIDER", "disabled")
        @instance_name = @client.instance_name
        @configured = @client.configured?
        @status_response ||= @client.connection_state if @configured
        @instances_response ||= @client.fetch_instances if @configured
        @current_whatsapp_instance = current_whatsapp_instance
        @current_whatsapp_number = whatsapp_number_from(@current_whatsapp_instance)
        @current_whatsapp_profile_name = whatsapp_profile_name_from(@current_whatsapp_instance)
        @deliveries = NotificationDelivery.order(created_at: :desc).limit(20)
        @incoming_events = IncomingWhatsAppEvent.recent.limit(20)
      end

      def current_whatsapp_instance
        instance_payloads.find { |payload| instance_name_for(payload) == @instance_name } || instance_payloads.first
      end

      def instance_payloads
        @instance_payloads ||= collect_instance_payloads(@instances_response&.dig(:body))
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
              nested_value(value, "response", "instances")
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
          nested_value(payload, "instance", "instanceName").presence
      end

      def whatsapp_number_from(payload)
        raw_number = [
          nested_value(payload, "number"),
          nested_value(payload, "phone"),
          nested_value(payload, "phoneNumber"),
          nested_value(payload, "displayPhoneNumber"),
          nested_value(payload, "ownerJid"),
          nested_value(payload, "jid"),
          nested_value(payload, "owner", "jid"),
          nested_value(payload, "profile", "id"),
          nested_value(payload, "instance", "ownerJid")
        ].compact_blank.first

        normalized_number = raw_number.to_s
        return if normalized_number.blank?

        digits = normalized_number.split("@").first.to_s.split(":").first.to_s.gsub(/[^\d]/, "")
        "+#{digits}" if digits.present?
      end

      def whatsapp_profile_name_from(payload)
        nested_value(payload, "profileName").presence ||
          nested_value(payload, "pushName").presence ||
          nested_value(payload, "profile", "name").presence
      end

      def nested_value(payload, *keys)
        keys.reduce(payload) do |current, key|
          current.is_a?(Hash) ? current[key] : nil
        end
      end
  end
end
