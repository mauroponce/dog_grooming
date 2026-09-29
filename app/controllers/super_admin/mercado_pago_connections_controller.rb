module SuperAdmin
  class MercadoPagoConnectionsController < BaseController
    def connect
      state = SecureRandom.urlsafe_base64(32)
      session[:platform_mercado_pago_oauth_state] = state
      redirect_to PlatformMercadoPago::OAuthClient.new.authorization_url(
        redirect_uri: callback_super_admin_mercado_pago_connection_url, state: state
      ), allow_other_host: true
    rescue PlatformMercadoPago::OAuthClient::Error => error
      redirect_to super_admin_billing_path, alert: error.message
    end

    def callback
      expected = session.delete(:platform_mercado_pago_oauth_state).to_s
      unless expected.present? && params[:state].present? &&
          ActiveSupport::SecurityUtils.secure_compare(expected, params[:state].to_s)
        redirect_to super_admin_billing_path, alert: "No pudimos validar la conexión con Mercado Pago."
        return
      end

      account = PlatformMercadoPagoAccount.current
      payload = PlatformMercadoPago::OAuthClient.new.exchange_code!(
        code: params[:code].to_s, redirect_uri: callback_super_admin_mercado_pago_connection_url
      )
      account.assign_from_oauth_response!(payload)
      profile = PlatformMercadoPago::Client.new(account: account).fetch_current_user!
      account.mercado_pago_user_id = profile["id"].to_s if profile["id"].present?
      account.mercado_pago_email = profile["email"] if profile["email"].present?
      account.save!
      redirect_to super_admin_billing_path, notice: "Tu cuenta de Mercado Pago quedó conectada para suscripciones."
    rescue PlatformMercadoPago::OAuthClient::Error, PlatformMercadoPago::Client::Error, KeyError => error
      redirect_to super_admin_billing_path, alert: error.message
    end
  end
end
