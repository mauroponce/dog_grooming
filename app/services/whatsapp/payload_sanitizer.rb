module WhatsApp
  class PayloadSanitizer
    SENSITIVE_KEYS = %w[
      api_key
      apikey
      authorization
      bearer
      secret
      signed_url
      token
    ].freeze
    LARGE_KEYS = %w[base64 media dataurl].freeze

    def self.call(value)
      new(value).call
    end

    def initialize(value)
      @value = value
    end

    def call
      sanitize(value)
    end

    private
      attr_reader :value

      def sanitize(object)
        case object
        when Hash
          object.to_h.transform_values.with_index do |entry_value, index|
            entry_key = object.keys[index].to_s.downcase
            if sensitive_key?(entry_key)
              "[filtrado]"
            elsif large_key?(entry_key)
              "[omitido]"
            else
              sanitize(entry_value)
            end
          end
        when Array
          object.map { |entry| sanitize(entry) }
        when String
          object.length > 1_000 ? "#{object.first(1_000)}...[truncado]" : object
        else
          object
        end
      end

      def sensitive_key?(key)
        SENSITIVE_KEYS.any? { |sensitive| key.include?(sensitive) }
      end

      def large_key?(key)
        LARGE_KEYS.any? { |large| key.include?(large) }
      end
  end
end
