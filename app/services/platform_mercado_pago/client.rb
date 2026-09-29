require "json"
require "net/http"
require "uri"
require "erb"

module PlatformMercadoPago
  class Client
    BASE_URL = "https://api.mercadopago.com"
    class Error < StandardError; end

    def initialize(account: PlatformMercadoPagoAccount.current)
      @account = account
    end

    def create_subscription!(business:, back_url:)
      payload = {
        reason: Business::SUBSCRIPTION_DETAILS.fetch(:name),
        external_reference: business.subscription.external_reference,
        payer_email: business.owner.email_address,
        auto_recurring: {
          frequency: 1,
          frequency_type: "months",
          transaction_amount: account.monthly_amount_cents / 100.0,
          currency_id: "ARS"
        },
        back_url: back_url,
        status: "pending"
      }
      post("/preapproval", payload)
    end

    def fetch_subscription!(id)
      get("/preapproval/#{ERB::Util.url_encode(id.to_s)}")
    end

    def fetch_authorized_payment!(id)
      get("/authorized_payments/#{ERB::Util.url_encode(id.to_s)}")
    end

    def search_authorized_payments!(subscription_id)
      get("/authorized_payments/search?#{URI.encode_www_form(preapproval_id: subscription_id, limit: 20)}")
    end

    def fetch_current_user!
      get("/users/me")
    end

    private
      attr_reader :account

      def get(path)
        request(Net::HTTP::Get.new(URI("#{BASE_URL}#{path}")))
      end

      def post(path, body)
        uri = URI("#{BASE_URL}#{path}")
        http_request = Net::HTTP::Post.new(uri)
        http_request["Content-Type"] = "application/json"
        http_request.body = JSON.generate(body)
        request(http_request)
      end

      def request(http_request)
        http_request["Authorization"] = "Bearer #{account.access_token_for_api!}"
        uri = http_request.uri
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { |http| http.request(http_request) }
        payload = JSON.parse(response.body.presence || "{}")
        raise Error, payload["message"].presence || "Mercado Pago respondió #{response.code}." unless response.is_a?(Net::HTTPSuccess)

        payload
      rescue JSON::ParserError
        raise Error, "Mercado Pago respondió un formato inválido."
      end
  end
end
