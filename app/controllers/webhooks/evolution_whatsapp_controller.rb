module Webhooks
  class EvolutionWhatsAppController < ApplicationController
    allow_unauthenticated_access
    skip_before_action :verify_authenticity_token

    def create
      return head :unauthorized unless authorized_webhook?

      event = IncomingWhatsAppEvent.create!(
        business: matched_business,
        instance_name: instance_name,
        event_type: event_type,
        sender: normalized_sender,
        message: message_text,
        payload: WhatsApp::PayloadSanitizer.call(webhook_payload),
        received_at: Time.current
      )
      process_opt_out!(event)

      head :ok
    end

    private
      def authorized_webhook?
        secret = ENV["EVOLUTION_WEBHOOK_SECRET"].to_s
        return false if secret.blank?

        ActiveSupport::SecurityUtils.secure_compare(auth_header_token, secret) ||
          ActiveSupport::SecurityUtils.secure_compare(params[:secret].to_s, secret)
      rescue ArgumentError
        false
      end

      def auth_header_token
        request.authorization.to_s.delete_prefix("Bearer ").strip
      end

      def webhook_payload
        @webhook_payload ||= request.request_parameters.presence || JSON.parse(request.raw_post.presence || "{}")
      rescue JSON::ParserError
        {}
      end

      def event_type
        webhook_payload["event"].presence ||
          webhook_payload["type"].presence ||
          webhook_payload.dig("data", "event").presence ||
          "unknown"
      end

      def instance_name
        webhook_payload["instance"].presence ||
          webhook_payload["instanceName"].presence ||
          webhook_payload.dig("data", "instanceName").presence ||
          ENV.fetch("EVOLUTION_INSTANCE_NAME", "dog-grooming-main")
      end

      def sender
        webhook_payload.dig("data", "key", "remoteJid").presence ||
          webhook_payload.dig("data", "remoteJid").presence ||
          webhook_payload.dig("data", "sender").presence ||
          webhook_payload["sender"].presence
      end

      def normalized_sender
        PhoneNormalizer.normalize(sender.to_s.split("@").first)
      end

      def message_text
        webhook_payload.dig("data", "message", "conversation").presence ||
          webhook_payload.dig("data", "message", "extendedTextMessage", "text").presence ||
          webhook_payload.dig("message", "text").presence ||
          webhook_payload["text"].presence
      end

      def matched_business
        return if normalized_sender.blank?

        Business.find_by(whatsapp_notifications_phone: normalized_sender)
      end

      def process_opt_out!(event)
        return unless message_text.to_s.strip.casecmp("BAJA").zero?
        return if event.business.blank?

        event.business.update!(
          whatsapp_notifications_enabled: false,
          whatsapp_opted_out_at: Time.current
        )
      end
  end
end
