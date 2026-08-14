require "json"
require "net/http"
require "uri"
require "erb"

module MercadoPago
  class Client
    BASE_URL = "https://api.mercadopago.com"

    class Error < StandardError; end
    class MissingAccessToken < Error; end

    def self.for_connection(connection)
      if Credentials.test? && Credentials.access_token.present?
        new(access_token: Credentials.access_token)
      else
        new(connection: connection)
      end
    end

    def initialize(connection: nil, access_token: nil)
      @connection = connection
      @access_token = access_token
    end

    def create_preference!(payload)
      post_json("/checkout/preferences", payload)
    end

    def fetch_payment!(payment_id)
      get_json("/v1/payments/#{ERB::Util.url_encode(payment_id.to_s)}")
    end

    def fetch_current_user!
      get_json("/users/me")
    end

    private
      attr_reader :connection, :access_token

      def get_json(path)
        request(Net::HTTP::Get.new(uri_for(path)))
      end

      def post_json(path, payload)
        request = Net::HTTP::Post.new(uri_for(path))
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(payload)
        request(request)
      end

      def request(http_request)
        http_request["Authorization"] = "Bearer #{token}"
        response = Net::HTTP.start(http_request.uri.hostname, http_request.uri.port, use_ssl: true) { |http| http.request(http_request) }
        payload = parse_json(response.body)
        return payload if response.is_a?(Net::HTTPSuccess)

        raise Error, payload["message"].presence || payload.dig("error", "message").presence || payload["error"].presence || "Mercado Pago respondió #{response.code}."
      end

      def token
        access_token.presence ||
          connection&.access_token_for_api! ||
          Credentials.access_token.presence ||
          raise(MissingAccessToken, "Mercado Pago no está conectado.")
      end

      def uri_for(path)
        URI.parse("#{BASE_URL}#{path}")
      end

      def parse_json(body)
        JSON.parse(body.presence || "{}")
      rescue JSON::ParserError
        {}
      end
  end
end
