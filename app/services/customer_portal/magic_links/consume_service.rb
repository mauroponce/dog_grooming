module CustomerPortal
  module MagicLinks
    class ConsumeService
      Result = Struct.new(:email, :customer_ids, keyword_init: true)

      PURPOSE = "customer_portal_login"

      class InvalidToken < StandardError; end

      def self.call(...)
        new(...).call
      end

      def initialize(business:, token:)
        @business = business
        @token = token.to_s
      end

      def call
        raise InvalidToken if token.blank?

        token_record = business.customer_portal_access_tokens
          .where(purpose: PURPOSE, token_digest: CustomerPortalAccessToken.digest(token))
          .first

        raise InvalidToken if token_record.blank? || token_record.expired? || token_record.consumed?

        customers = business.customer_profiles.where(normalized_email: token_record.email).to_a
        raise InvalidToken if customers.blank?

        token_record.update!(consumed_at: Time.current)
        Result.new(email: token_record.email, customer_ids: customers.map(&:id))
      end

      private
        attr_reader :business, :token
    end
  end
end
