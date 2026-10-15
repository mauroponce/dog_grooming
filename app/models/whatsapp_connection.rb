class WhatsAppConnection < ApplicationRecord
  belongs_to :business
  validates :phone_number_id, :waba_id, presence: true, format: { with: /\A\d+\z/ }
  validates :phone_number_id, :business_id, uniqueness: true
  after_save_commit :schedule_coexistence_sync, if: -> { saved_change_to_connected_at? && verified_at.present? }

  def access_token
    TokenEncryptor.decrypt(access_token_ciphertext)
  end

  def access_token=(value)
    self.access_token_ciphertext = TokenEncryptor.encrypt(value)
  end

  def connected?
    disconnected_at.nil? && access_token_ciphertext.present? && !credentials_expired? && authorization_failed_at.nil?
  end

  def credentials_expired?
    [ token_expires_at, data_access_expires_at ].compact.any? { |time| time <= Time.current }
  end

  def reconnect_soon?
    [ token_expires_at, data_access_expires_at ].compact.any? { |time| time <= 7.days.from_now }
  end

  def coexistence?
    verified_at.present?
  end

  def disconnect!
    update!(access_token_ciphertext: nil, disconnected_at: Time.current, automation_enabled: false, templates_approved: false)
  end

  private
    def schedule_coexistence_sync
      WhatsApp::SyncCoexistenceDataJob.perform_later(id, connected_at.iso8601(6))
    end
end
