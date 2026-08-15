module Admin
  class MercadoPagoConnectionsController < BaseController
    def connect
      unless MercadoPago::OAuthClient.configured?
        redirect_to admin_settings_path(anchor: "cuentas-de-cobro"), alert: "Configurá las credenciales OAuth de Mercado Pago para #{MercadoPago::Credentials.environment_label}."
        return
      end

      session[:mercado_pago_oauth_state] = state
      redirect_to MercadoPago::OAuthClient.new.authorization_url(
        redirect_uri: callback_admin_mercado_pago_connection_url,
        state: state
      ), allow_other_host: true
    end

    def callback
      unless valid_state?
        redirect_to admin_settings_path(anchor: "cuentas-de-cobro"), alert: "No pudimos validar la conexión con Mercado Pago."
        return
      end

      payload = MercadoPago::OAuthClient.new.exchange_code!(
        code: params[:code].to_s,
        redirect_uri: callback_admin_mercado_pago_connection_url
      )
      connection = @business.mercado_pago_connection || @business.build_mercado_pago_connection
      connection.assign_from_oauth_response!(payload)
      assign_mercado_pago_account_profile(connection)
      connection.save!

      session.delete(:mercado_pago_oauth_state)
      redirect_to admin_settings_path(anchor: "cuentas-de-cobro"), notice: "Mercado Pago quedó conectado."
    rescue MercadoPago::OAuthClient::Error, KeyError => error
      redirect_to admin_settings_path(anchor: "cuentas-de-cobro"), alert: error.message
    end

    def destroy
      @business.mercado_pago_connection&.disconnect!
      enabled_payment_methods = @business.enabled_payment_methods - [ "mercado_pago" ]
      @business.update!(preferences: @business.preferences.to_h.merge("enabled_payment_methods" => enabled_payment_methods.presence || [ "manual_transfer" ]))

      redirect_to admin_settings_path(anchor: "cuentas-de-cobro"), notice: "Mercado Pago fue desconectado."
    end

    private
      def state
        @state ||= SecureRandom.urlsafe_base64(32)
      end

      def valid_state?
        params[:state].present? &&
          session[:mercado_pago_oauth_state].present? &&
          ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, session[:mercado_pago_oauth_state].to_s)
      rescue ArgumentError
        false
      end

      def assign_mercado_pago_account_profile(connection)
        connection.assign_account_profile!(MercadoPago::Client.new(connection: connection).fetch_current_user!)
      rescue MercadoPago::Client::Error
        nil
      end
  end
end
