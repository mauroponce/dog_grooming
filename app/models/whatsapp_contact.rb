class WhatsAppContact < ApplicationRecord
  belongs_to :business
  before_validation -> { self.phone = PhoneNumber.normalize(phone) }
  validates :phone, presence: true, uniqueness: { scope: :business_id }
  validates :whatsapp_id, format: { with: /\A\d+\z/ }, allow_blank: true

  def whatsapp_id
    TokenEncryptor.decrypt(whatsapp_id_ciphertext)
  end

  def whatsapp_id=(value)
    self.whatsapp_id_ciphertext = TokenEncryptor.encrypt(value)
  end

  def window_open?
    return false unless last_inbound_at.present? && last_inbound_at > 24.hours.ago

    connection = business.whatsapp_connection
    # A previous line's inbound message must not authorize a new connection.
    !connection&.coexistence? || connection.connected_at.nil? || last_inbound_at >= connection.connected_at
  end

  def paused?
    paused_until.present? && paused_until.future?
  end
end
