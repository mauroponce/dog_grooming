module SuperAdmin
  class MercadoPagoConnectionsController < BaseController
    def connect
      redirect_to super_admin_billing_path, alert: "Configurá las credenciales OAuth de Mercado Pago." and return unless MercadoPago::OAuthClient.configured?
      session[:billing_mercado_pago_oauth_state] = state
      redirect_to MercadoPago::OAuthClient.new.authorization_url(redirect_uri: callback_super_admin_mercado_pago_connection_url, state: state), allow_other_host: true
    end

    def callback
      unless valid_state?
        redirect_to super_admin_billing_path, alert: "No pudimos validar la conexión con Mercado Pago." and return
      end
      connection = BillingMercadoPagoConnection.current
      connection.assign_from_oauth_response!(MercadoPago::OAuthClient.new.exchange_code!(code: params[:code].to_s, redirect_uri: callback_super_admin_mercado_pago_connection_url))
      connection.assign_account_profile!(MercadoPago::Client.new(connection: connection).fetch_current_user!)
      connection.save!
      session.delete(:billing_mercado_pago_oauth_state)
      redirect_to super_admin_billing_path, notice: "La cuenta de Mercado Pago de Cita.pet quedó conectada."
    rescue MercadoPago::OAuthClient::Error, MercadoPago::Client::Error, KeyError => error
      redirect_to super_admin_billing_path, alert: error.message
    end

    def destroy
      BillingMercadoPagoConnection.current.disconnect!
      redirect_to super_admin_billing_path, notice: "La cuenta de Mercado Pago de Cita.pet fue desconectada."
    end

    private
      def state = @state ||= SecureRandom.urlsafe_base64(32)
      def valid_state?
        params[:state].present? && session[:billing_mercado_pago_oauth_state].present? && ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, session[:billing_mercado_pago_oauth_state].to_s)
      rescue ArgumentError
        false
      end
  end
end
