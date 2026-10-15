require "net/http"

module WhatsApp
  class CloudClient
    class Error < StandardError; end
    class UncertainDelivery < Error; end
    class RetryableError < Error; end

    def initialize(connection: nil)
      @connection = connection
    end

    def send_message!(payload)
      request(:post, "#{@connection.phone_number_id}/messages", payload, token: @connection.access_token)
    rescue Net::ReadTimeout, Net::WriteTimeout, EOFError, Errno::ECONNRESET
      raise UncertainDelivery, "No se pudo confirmar la recepción de Meta."
    end

    def get!(path, token:)
      request(:get, path, nil, token: token)
    end

    def post!(path, payload, token:)
      request(:post, path, payload, token: token)
    end

    private
      def request(method, path, payload, token:)
        version = ENV.fetch("META_GRAPH_VERSION", "v25.0")
        raise Error, "Versión de Meta inválida" unless version.match?(/\Av\d+\.\d+\z/)

        uri = URI("https://graph.facebook.com/#{version}/#{path}")
        req = method == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
        req["Authorization"] = "Bearer #{token}"
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(payload) if payload
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15, write_timeout: 15) { |http| http.request(req) }
        raise RetryableError, "Meta limitó temporalmente los envíos" if response.code == "429"
        raise UncertainDelivery, "Error temporal de Meta" if response.code.to_i >= 500
        raise Error, "Meta respondió HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      rescue JSON::ParserError
        raise UncertainDelivery, "Respuesta de Meta inválida"
      end
  end
end
