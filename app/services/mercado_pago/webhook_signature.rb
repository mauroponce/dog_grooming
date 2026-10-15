require "openssl"

module MercadoPago
  class WebhookSignature
    def self.valid?(headers:, params:)
      new(headers:, params:).valid?
    end

    def initialize(headers:, params:)
      @headers = headers
      @params = params
    end

    def valid?
      secret = ENV["MERCADO_PAGO_WEBHOOK_SECRET"].to_s
      return !Rails.env.production? if secret.blank?
      return false if request_id.blank? || signature_header.blank? || data_id.blank?

      ActiveSupport::SecurityUtils.secure_compare(expected_signature(secret), received_signature)
    rescue ArgumentError
      false
    end

    private
      attr_reader :headers, :params

      def expected_signature(secret)
        OpenSSL::HMAC.hexdigest("SHA256", secret, "id:#{data_id};request-id:#{request_id};ts:#{timestamp};")
      end

      def received_signature
        signature_parts.fetch("v1", "")
      end

      def timestamp
        signature_parts.fetch("ts", "")
      end

      def signature_parts
        @signature_parts ||= signature_header.to_s.split(",").filter_map do |part|
          key, value = part.split("=", 2).map(&:strip)
          [ key, value ] if key.present? && value.present?
        end.to_h
      end

      def signature_header
        headers["x-signature"].presence || headers["X-Signature"].presence
      end

      def request_id
        headers["x-request-id"].presence || headers["X-Request-Id"].presence
      end

      def data_id
        params.dig("data", "id").presence ||
          params["data.id"].presence ||
          params["id"].presence
      end
  end
end
