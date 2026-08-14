module CustomerPortal
  module MagicLinks
    class CreateService
      Result = Struct.new(:sent, :throttled, :channel, keyword_init: true)

      EXPIRATION = 30.minutes
      THROTTLE_WINDOW = 60.seconds
      PURPOSE = "customer_portal_login"

      def self.call(...)
        new(...).call
      end

      def initialize(business:, contact: nil, email: nil, request: nil, whatsapp_client: WhatsApp::EvolutionClient.new)
        @business = business
        @contact = contact.presence || email
        @email = email_contact? ? normalize_email(@contact) : nil
        @phone = email.present? && contact.blank? ? nil : normalize_phone(@contact)
        @request = request
        @whatsapp_client = whatsapp_client
      end

      def call
        return Result.new(sent: false, throttled: false, channel: nil) if contact.blank?

        return send_email_link if email.present?
        Result.new(sent: false, throttled: false, channel: "email")
      end

      private
        attr_reader :business, :contact, :email, :phone, :request, :whatsapp_client

        def send_email_link
          customers = matching_customers
          return Result.new(sent: false, throttled: false, channel: "email") if customers.blank?
          return Result.new(sent: false, throttled: true, channel: "email") if throttled?

          raw_token = SecureRandom.urlsafe_base64(32)
          token_record = business.customer_portal_access_tokens.create!(
            customer_profile: customers.first,
            email: email,
            token_digest: CustomerPortalAccessToken.digest(raw_token),
            purpose: PURPOSE,
            expires_at: EXPIRATION.from_now,
            last_sent_at: Time.current,
            request_ip: request&.remote_ip,
            request_user_agent: request&.user_agent.to_s.truncate(500)
          )

          CustomerPortalMailer.magic_link(token_record, raw_token).deliver_later
          Result.new(sent: true, throttled: false, channel: "email")
        end

        def send_whatsapp_link
          return Result.new(sent: false, throttled: false, channel: "whatsapp") unless WhatsApp::AutomatedNotifications.enabled?

          customer = matching_phone_customers.first
          return Result.new(sent: false, throttled: false, channel: "whatsapp") if customer.blank?
          return Result.new(sent: false, throttled: true, channel: "whatsapp") if phone_throttled?
          return Result.new(sent: false, throttled: false, channel: "whatsapp") unless whatsapp_provider_enabled?

          delivery = NotificationDelivery.create!(
            business: business,
            channel: "whatsapp_evolution",
            recipient: normalized_delivery_phone(customer),
            template: "customer_portal_link",
            status: "queued",
            payload: {
              customer_profile_id: customer.id,
              request_ip: request&.remote_ip,
              request_user_agent: request&.user_agent.to_s.truncate(500)
            }.compact
          )

          response = whatsapp_client.send_text(number: customer.phone.presence || phone, text: customer.portal_access_whatsapp_message)
          if response[:success]
            delivery.update!(status: "sent", sent_at: Time.current, provider_message_id: provider_message_id(response[:body]), payload: delivery.payload.merge(response: response))
            Result.new(sent: true, throttled: false, channel: "whatsapp")
          else
            delivery.update!(status: "failed", error_message: response[:error].presence || "Evolution API respondió con estado #{response[:status]}", payload: delivery.payload.merge(response: response))
            Result.new(sent: false, throttled: false, channel: "whatsapp")
          end
        end

        def matching_customers
          @matching_customers ||= business.customer_profiles.where(normalized_email: email).to_a
        end

        def matching_phone_customers
          @matching_phone_customers ||= begin
            return [] if phone.blank?

            business.customer_profiles.where(normalized_phone: phone_lookup_values(phone)).order(:id).to_a
          end
        end

        def throttled?
          business.customer_portal_access_tokens
            .where(email: email, purpose: PURPOSE)
            .where("last_sent_at > ? OR created_at > ?", THROTTLE_WINDOW.ago, THROTTLE_WINDOW.ago)
            .exists?
        end

        def phone_throttled?
          NotificationDelivery
            .where(business: business, channel: "whatsapp_evolution", template: "customer_portal_link", recipient: phone_lookup_values(phone))
            .where("created_at > ?", THROTTLE_WINDOW.ago)
            .exists?
        end

        def whatsapp_provider_enabled?
          ENV.fetch("WHATSAPP_PROVIDER", "").to_s == "evolution" && whatsapp_client.configured?
        end

        def normalized_delivery_phone(customer)
          PhoneNormalizer.normalize(customer.phone).presence ||
            PhoneNormalizer.normalize(phone).presence ||
            PhoneNumber.normalize(customer.phone).presence ||
            phone
        end

        def email_contact?
          @contact.to_s.include?("@")
        end

        def normalize_email(value)
          value.to_s.strip.downcase.presence
        end

        def normalize_phone(value)
          PhoneNumber.normalize(value).presence
        end

        def phone_lookup_values(value)
          PhoneNumber.lookup_values(value)
        end

        def provider_message_id(body)
          body.to_h.dig("key", "id").presence ||
            body.to_h.dig("message", "key", "id").presence ||
            body.to_h.dig("data", "key", "id").presence
        end
    end
  end
end
