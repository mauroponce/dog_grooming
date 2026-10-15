class BillingMercadoPagoConnection < ApplicationRecord
  SINGLETON_KEY = "cita_pet_billing".freeze

  def self.current
    find_or_create_by!(singleton_key: SINGLETON_KEY)
  end

  def connected?
    disconnected_at.blank? && access_token_ciphertext.present?
  end

  def access_token
    TokenEncryptor.decrypt(access_token_ciphertext)
  end

  def access_token=(value)
    self.access_token_ciphertext = TokenEncryptor.encrypt(value)
  end

  def refresh_token
    TokenEncryptor.decrypt(refresh_token_ciphertext)
  end

  def refresh_token=(value)
    self.refresh_token_ciphertext = TokenEncryptor.encrypt(value)
  end

  def expired?
    expires_at.present? && expires_at <= 5.minutes.from_now
  end

  def access_token_for_api!
    refresh_access_token! if expired? && refresh_token.present?
    access_token.presence || raise(MercadoPago::Client::MissingAccessToken, "La cuenta de cobro de Cita.pet no está conectada.")
  end

  def assign_from_oauth_response!(payload)
    data = payload.to_h
    self.access_token = data.fetch("access_token")
    self.refresh_token = data["refresh_token"] if data["refresh_token"].present?
    self.mercado_pago_user_id = data["user_id"].to_s if data["user_id"].present?
    self.expires_at = data["expires_in"].to_i.seconds.from_now if data["expires_in"].present?
    self.connected_at ||= Time.current
    self.disconnected_at = nil
    self.metadata = metadata.to_h.merge("live_mode" => data["live_mode"], "scope" => data["scope"]).compact
  end

  def assign_account_profile!(payload)
    data = payload.to_h
    self.mercado_pago_user_id = data["id"].to_s if data["id"].present?
    self.mercado_pago_email = data["email"].to_s if data["email"].present?
    self.mercado_pago_nickname = data["nickname"].to_s if data["nickname"].present?
  end

  def refresh_access_token!
    assign_from_oauth_response!(MercadoPago::OAuthClient.new.refresh_token!(refresh_token))
    save!
  end

  def disconnect!
    update!(access_token_ciphertext: nil, refresh_token_ciphertext: nil, disconnected_at: Time.current)
  end
end
