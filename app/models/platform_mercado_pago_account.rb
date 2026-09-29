class PlatformMercadoPagoAccount < ApplicationRecord
  SINGLETON_KEY = "primary"

  validates :singleton_key, presence: true, uniqueness: true
  validates :monthly_amount_cents, numericality: { only_integer: true, greater_than: 0 }

  def self.current
    find_or_initialize_by(singleton_key: SINGLETON_KEY)
  end

  def connected?
    return false if disconnected_at.present? || access_token_ciphertext.blank?
    return true if ENV["PLATFORM_MERCADO_PAGO_ENV"].to_s == "test"

    live_mode == true
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

  def access_token_for_api!
    raise PlatformMercadoPago::Client::Error, "Conectá una cuenta de Mercado Pago válida para este entorno." unless connected?

    refresh_access_token! if expires_at.present? && expires_at <= 5.minutes.from_now
    access_token.presence || raise(PlatformMercadoPago::Client::Error, "Conectá la cuenta de Mercado Pago del super admin.")
  end

  def assign_from_oauth_response!(payload)
    self.access_token = payload.fetch("access_token")
    self.refresh_token = payload["refresh_token"] if payload["refresh_token"].present?
    self.mercado_pago_user_id = payload["user_id"].to_s if payload["user_id"].present?
    self.live_mode = ActiveModel::Type::Boolean.new.cast(payload["live_mode"]) if payload.key?("live_mode")
    self.expires_at = payload["expires_in"].to_i.seconds.from_now if payload["expires_in"].present?
    self.connected_at = Time.current
    self.disconnected_at = nil
  end

  def refresh_access_token!
    raise PlatformMercadoPago::Client::Error, "Volvé a conectar Mercado Pago del super admin." if refresh_token.blank?

    assign_from_oauth_response!(PlatformMercadoPago::OAuthClient.new.refresh_token!(refresh_token))
    save!
  end

  def disconnect!
    update!(access_token_ciphertext: nil, refresh_token_ciphertext: nil, disconnected_at: Time.current)
  end
end
