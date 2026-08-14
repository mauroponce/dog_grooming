class TokenEncryptor
  def self.encrypt(value)
    return if value.blank?

    encryptor.encrypt_and_sign(value)
  end

  def self.decrypt(value)
    return if value.blank?

    encryptor.decrypt_and_verify(value)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def self.encryptor
    key = Rails.application.key_generator.generate_key("business-token-encryption", ActiveSupport::MessageEncryptor.key_len)
    ActiveSupport::MessageEncryptor.new(key)
  end
end
