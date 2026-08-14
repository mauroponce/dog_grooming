class MercadoPagoConnection < ApplicationRecord
  belongs_to :business

  validates :business_id, uniqueness: true

  scope :connected, -> { where(disconnected_at: nil).where.not(access_token_ciphertext: [ nil, "" ]) }

  def connected?
    disconnected_at.blank? && access_token_ciphertext.present?
  end

  def test_connection?
    live_mode = metadata.to_h["live_mode"]
    return !ActiveModel::Type::Boolean.new.cast(live_mode) unless live_mode.nil?

    access_token.to_s.start_with?("TEST-")
  end

  def available_for_current_environment?
    return false unless connected?
    return true if MercadoPago::Credentials.test?

    !test_connection?
  end

  def requires_production_reconnection?
    connected? && !MercadoPago::Credentials.test? && test_connection?
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
    refresh_access_token! if expired? && refresh_token.present?
    access_token.presence || raise(MercadoPago::Client::MissingAccessToken, "Mercado Pago no está conectado.")
  end

  def expired?
    expires_at.present? && expires_at <= 5.minutes.from_now
  end

  def assign_from_oauth_response!(payload)
    data = payload.to_h
    self.access_token = data.fetch("access_token")
    self.refresh_token = data["refresh_token"] if data["refresh_token"].present?
    self.public_key = data["public_key"] if data["public_key"].present?
    self.mercado_pago_user_id = data["user_id"].to_s if data["user_id"].present?
    self.expires_at = data["expires_in"].present? ? data["expires_in"].to_i.seconds.from_now : nil
    self.connected_at ||= Time.current
    self.disconnected_at = nil
    self.metadata = metadata.to_h.merge(
      "scope" => data["scope"],
      "token_type" => data["token_type"],
      "live_mode" => data["live_mode"]
    ).compact
  end

  def assign_account_profile!(payload)
    data = payload.to_h
    self.mercado_pago_user_id = data["id"].to_s if data["id"].present?
    self.mercado_pago_email = data["email"].to_s if data["email"].present?
    self.mercado_pago_nickname = data["nickname"].to_s if data["nickname"].present?
    self.metadata = metadata.to_h.merge(
      "account_site_id" => data["site_id"],
      "account_status" => data["status"].is_a?(Hash) ? data["status"]["site_status"] : nil,
      "account_type" => data.dig("status", "mercadopago_account_type")
    ).compact
  end

  def mercado_pago_account_label
    mercado_pago_email.presence ||
      mercado_pago_nickname.presence ||
      mercado_pago_user_id.presence
  end

  def refresh_access_token!
    assign_from_oauth_response!(MercadoPago::OAuthClient.new.refresh_token!(refresh_token))
    save!
  end

  def disconnect!
    update!(
      access_token_ciphertext: nil,
      refresh_token_ciphertext: nil,
      disconnected_at: Time.current
    )
  end
end
