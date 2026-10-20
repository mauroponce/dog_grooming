require "json"
require "net/http"
require "uri"

module MercadoPago
  class OAuthClient
    BASE_URL = "https://api.mercadopago.com"
    AUTHORIZATION_URL = "https://auth.mercadopago.com/authorization"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    class Error < StandardError; end

    def self.configured?
      Credentials.oauth_configured?
    end

    def self.client_id
      Credentials.client_id
    end

    def self.client_secret
      Credentials.client_secret
    end

    def self.redirect_uri
      ENV["MERCADO_PAGO_REDIRECT_URI"].presence ||
        Rails.application.routes.url_helpers.callback_admin_mercado_pago_connection_url(
          host: AppUrl.host,
          protocol: AppUrl.protocol
        )
    end

    def authorization_url(redirect_uri:, state:)
      raise Error, "Mercado Pago OAuth no está configurado." unless self.class.configured?

      uri = URI.parse(AUTHORIZATION_URL)
      uri.query = URI.encode_www_form(
        client_id: self.class.client_id,
        response_type: "code",
        platform_id: "mp",
        redirect_uri: redirect_uri,
        state: state
      )
      uri.to_s
    end

    def exchange_code!(code:, redirect_uri:)
      body = {
        client_secret: self.class.client_secret,
        client_id: self.class.client_id,
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri
      }
      body[:test_token] = true if Credentials.test?

      post_json("/oauth/token", body)
    end

    def refresh_token!(refresh_token)
      post_json("/oauth/token",
        client_secret: self.class.client_secret,
        client_id: self.class.client_id,
        grant_type: "refresh_token",
        refresh_token: refresh_token
      )
    end

    private
      def post_json(path, body)
        raise Error, "Mercado Pago OAuth no está configurado." unless self.class.configured?

        request = Net::HTTP::Post.new(uri_for(path))
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)

        response = Net::HTTP.start(
          request.uri.hostname,
          request.uri.port,
          use_ssl: true,
          open_timeout: OPEN_TIMEOUT,
          read_timeout: READ_TIMEOUT
        ) { |http| http.request(request) }
        payload = parse_json(response.body)
        return payload if response.is_a?(Net::HTTPSuccess)

        raise Error, payload["message"].presence || payload["error"].presence || "Mercado Pago respondió #{response.code}."
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, EOFError, Errno::ECONNRESET, Errno::ECONNREFUSED => error
        raise Error, "No pudimos comunicarnos con Mercado Pago (#{error.class.name.demodulize})."
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
