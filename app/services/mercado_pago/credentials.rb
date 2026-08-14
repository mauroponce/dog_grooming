module MercadoPago
  class Credentials
    TEST_ENVIRONMENTS = %w[test sandbox].freeze

    class << self
      def environment
        raw_environment = ENV["MERCADO_PAGO_ENV"].presence || ENV["MP_ENV"].presence
        TEST_ENVIRONMENTS.include?(raw_environment.to_s.downcase) ? "test" : "production"
      end

      def test?
        environment == "test"
      end

      def public_key
        fetch("PUBLIC_KEY")
      end

      def access_token
        fetch("ACCESS_TOKEN")
      end

      def client_id
        environment_specific_value("CLIENT_ID").presence ||
          generic_value("CLIENT_ID").presence ||
          inferred_client_id_from_access_token
      end

      def client_secret
        fetch("CLIENT_SECRET")
      end

      def oauth_configured?
        client_id.present? && client_secret.present?
      end

      def environment_label
        test? ? "prueba" : "producción"
      end

      private
        def fetch(name)
          environment_specific_value(name).presence || generic_value(name)
        end

        def environment_specific_value(name)
          prefix = test? ? "TEST" : "PRODUCTION"
          ENV["MERCADO_PAGO_#{prefix}_#{name}"].presence ||
            ENV["MP_#{prefix}_#{name}"].presence
        end

        def generic_value(name)
          ENV["MERCADO_PAGO_#{name}"].presence ||
            ENV["MP_#{name}"].presence
        end

        def inferred_client_id_from_access_token
          access_token = environment_specific_value("ACCESS_TOKEN").presence || generic_value("ACCESS_TOKEN")
          access_token.to_s[/\AAPP_USR-(\d+)-/, 1].presence
        end
    end
  end
end
