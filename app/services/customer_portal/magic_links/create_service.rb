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

      def initialize(business:, contact: nil, email: nil, request: nil)
        @business = business
        @contact = contact.presence || email
        @email = email_contact? ? normalize_email(@contact) : nil
        @request = request
      end

      def call
        return Result.new(sent: false, throttled: false, channel: nil) if contact.blank?

        return send_email_link if email.present?
        Result.new(sent: false, throttled: false, channel: "email")
      end

      private
        attr_reader :business, :contact, :email, :request

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

        def matching_customers
          @matching_customers ||= business.customer_profiles.where(normalized_email: email).to_a
        end

        def throttled?
          business.customer_portal_access_tokens
            .where(email: email, purpose: PURPOSE)
            .where("last_sent_at > ? OR created_at > ?", THROTTLE_WINDOW.ago, THROTTLE_WINDOW.ago)
            .exists?
        end

        def email_contact?
          @contact.to_s.include?("@")
        end

        def normalize_email(value)
          value.to_s.strip.downcase.presence
        end

    end
  end
end
