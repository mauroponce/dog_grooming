class WhatsAppConnection < ApplicationRecord
  belongs_to :business
  validates :phone_number_id, :waba_id, presence: true, format: { with: /\A\d+\z/ }
  validates :phone_number_id, :business_id, uniqueness: true

  def access_token
    TokenEncryptor.decrypt(access_token_ciphertext)
  end

  def access_token=(value)
    self.access_token_ciphertext = TokenEncryptor.encrypt(value)
  end

  def connected?
    disconnected_at.nil? && access_token_ciphertext.present?
  end
end
