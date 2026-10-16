require "net/http"

module WhatsApp
  class CloudClient
    class Error < StandardError
      attr_reader :code, :subcode, :http_status, :error_type, :fbtrace_id, :provider_message

      def initialize(message = "No se pudo completar la solicitud a Meta", code: nil, subcode: nil, http_status: nil, error_type: nil, fbtrace_id: nil, provider_message: nil)
        @code, @subcode, @http_status = code, subcode, http_status
        @error_type, @fbtrace_id = error_type, fbtrace_id
        @provider_message = provider_message
        super(message)
      end

      def authorization_error?
        code.to_i.in?([ 102, 190 ])
      end

      def diagnostic
        {
          "http_status" => http_status,
          "code" => code,
          "subcode" => subcode,
          "type" => error_type,
          "message" => provider_message,
          "fbtrace_id" => fbtrace_id
        }.compact
      end
    end
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
        version = SignupConfiguration.graph_version
        raise Error, "Versión de Meta inválida" unless version.match?(/\Av\d+\.\d+\z/)

        uri = URI("https://graph.facebook.com/#{version}/#{path}")
        req = method == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
        req["Authorization"] = "Bearer #{token}"
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(payload) if payload
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15, write_timeout: 15) { |http| http.request(req) }
        raise RetryableError, "Meta limitó temporalmente los envíos" if response.code == "429"
        raise UncertainDelivery, "Error temporal de Meta" if response.code.to_i >= 500
        unless response.is_a?(Net::HTTPSuccess)
          error = JSON.parse(response.body).fetch("error", {})
          raise Error.new(
            "Meta respondió HTTP #{response.code}",
            code: error["code"],
            subcode: error["error_subcode"],
            http_status: response.code.to_i,
            error_type: error["type"],
            fbtrace_id: error["fbtrace_id"],
            provider_message: sanitize_provider_message(error["message"])
          )
        end

        JSON.parse(response.body)
      rescue JSON::ParserError
        raise UncertainDelivery, "Respuesta de Meta inválida"
      rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, EOFError, Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError, OpenSSL::SSL::SSLError
        raise UncertainDelivery, "No se pudo confirmar la respuesta de Meta. Volvé a conectar la cuenta."
      end

      def sanitize_provider_message(message)
        message.to_s.scrub[0, 500].gsub(/\b(?:access[\s_-]?token|authorization|app[\s_-]?secret|client[\s_-]?secret)\b\s*[:=]\s*\S+/i, "[REDACTED]")
      end
  end
end
