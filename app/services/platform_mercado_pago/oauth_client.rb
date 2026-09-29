require "json"
require "net/http"
require "uri"

module PlatformMercadoPago
  class OAuthClient
    AUTHORIZATION_URL = "https://auth.mercadopago.com/authorization"
    TOKEN_URL = "https://api.mercadopago.com/oauth/token"

    class Error < StandardError; end

    def self.client_id
      ENV["PLATFORM_MERCADO_PAGO_CLIENT_ID"].presence
    end

    def self.client_secret
      ENV["PLATFORM_MERCADO_PAGO_CLIENT_SECRET"].presence
    end

    def self.configured?
      client_id.present? && client_secret.present?
    end

    def authorization_url(redirect_uri:, state:)
      raise Error, "Configurá PLATFORM_MERCADO_PAGO_CLIENT_ID y PLATFORM_MERCADO_PAGO_CLIENT_SECRET." unless self.class.configured?

      uri = URI(AUTHORIZATION_URL)
      uri.query = URI.encode_www_form(client_id: self.class.client_id, response_type: "code", platform_id: "mp", redirect_uri: redirect_uri, state: state)
      uri.to_s
    end

    def exchange_code!(code:, redirect_uri:)
      values = { grant_type: "authorization_code", code: code, redirect_uri: redirect_uri }
      values[:test_token] = true if ENV["PLATFORM_MERCADO_PAGO_ENV"].to_s == "test"
      post_token(values)
    end

    def refresh_token!(token)
      post_token(grant_type: "refresh_token", refresh_token: token)
    end

    private
      def post_token(values)
        raise Error, "Configurá las credenciales de Mercado Pago del super admin." unless self.class.configured?

        uri = URI(TOKEN_URL)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(values.merge(client_id: self.class.client_id, client_secret: self.class.client_secret))
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { |http| http.request(request) }
        payload = JSON.parse(response.body.presence || "{}")
        raise Error, payload["message"].presence || "Mercado Pago respondió #{response.code}." unless response.is_a?(Net::HTTPSuccess)

        payload
      rescue JSON::ParserError
        raise Error, "Mercado Pago respondió un formato inválido."
      end
  end
end
