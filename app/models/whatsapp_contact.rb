class WhatsAppContact < ApplicationRecord
  belongs_to :business
  before_validation -> { self.phone = PhoneNumber.normalize(phone) }
  validates :phone, presence: true, uniqueness: { scope: :business_id }

  def window_open?
    last_inbound_at.present? && last_inbound_at > 24.hours.ago
  end

  def paused?
    paused_until.present? && paused_until.future?
  end
end
