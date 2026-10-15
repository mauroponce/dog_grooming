require "openssl"

module Webhooks
  class WhatsAppController < ActionController::Base
    # Only this external POST uses Meta's signature in place of a CSRF token.
    skip_before_action :verify_authenticity_token, only: :create

    def verify
      token = ENV["WHATSAPP_WEBHOOK_VERIFY_TOKEN"].to_s
      if token.present? && params["hub.mode"] == "subscribe" && ActiveSupport::SecurityUtils.secure_compare(token, params["hub.verify_token"].to_s)
        render plain: params["hub.challenge"].to_s
      else
        head :forbidden
      end
    end

    def create
      secret = ENV["META_APP_SECRET"].to_s
      signature = request.headers["X-Hub-Signature-256"].to_s
      expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, request.raw_post)}"
      return head :unauthorized unless secret.present? && ActiveSupport::SecurityUtils.secure_compare(expected, signature)

      payload = JSON.parse(request.raw_post)
      return head :bad_request unless valid_payload?(payload)

      WhatsAppEvent.transaction do
        Array(payload["entry"]).each do |entry|
          Array(entry["changes"]).each do |change|
            value = change.fetch("value", {})
            connection = WhatsAppConnection.find_by(phone_number_id: value.dig("metadata", "phone_number_id"), waba_id: entry["id"], disconnected_at: nil)
            unless connection
              Rails.logger.info("whatsapp_webhook_unmapped")
              next
            end

            if change["field"] == "smb_message_echoes"
              Array(value["message_echoes"]).each { |message| persist(connection, message, "human") }
            elsif change["field"] == "messages"
              Array(value["messages"]).each do |message|
                name = Array(value["contacts"]).find { |contact| contact["wa_id"] == message["from"] }&.dig("profile", "name")
                persist(connection, message.merge("contact_name" => name), "inbound")
              end
              Array(value["statuses"]).each { |status| persist(connection, status, "status:#{status['status']}") }
            end
          end
        end
      end
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private
      def valid_payload?(payload)
        return false unless payload.is_a?(Hash) && payload["object"] == "whatsapp_business_account" && payload["entry"].is_a?(Array)

        payload["entry"].all? do |entry|
          entry.is_a?(Hash) && entry["changes"].is_a?(Array) && entry["changes"].all? do |change|
            next false unless change.is_a?(Hash) && change["value"].is_a?(Hash)

            value = change["value"]
            next false if value["metadata"] && !value["metadata"].is_a?(Hash)

            %w[messages statuses message_echoes contacts].all? do |key|
              !value.key?(key) || (value[key].is_a?(Array) && value[key].all? { |item| item.is_a?(Hash) })
            end
          end
        end
      end

      def persist(connection, message, kind)
        return if message["id"].blank?

        # Store only fields needed for routing, not media or conversation history.
        data = message.slice("id", "from", "to", "timestamp", "text", "interactive", "contact_name", "status", "biz_opaque_callback_data")
        event = connection.business.whatsapp_events.create_or_find_by!(provider_id: message.fetch("id"), kind: kind) { |record| record.payload = data }
        # A retry also repairs a commit followed by a failed enqueue.
        WhatsApp::ProcessEventJob.perform_later(event.id) if !event.previously_new_record? && event.processed_at.nil?
        Rails.logger.info("whatsapp_webhook_received business_id=#{connection.business_id} event_id=#{event.id}")
      end
  end
end
