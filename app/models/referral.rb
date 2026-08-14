class Referral < ApplicationRecord
  STATUSES = %w[pending booked rewarded dismissed].freeze

  belongs_to :business
  belongs_to :referrer_customer, class_name: "CustomerProfile"
  belongs_to :referred_customer, class_name: "CustomerProfile", optional: true

  before_validation :normalize_referred_phone

  validates :status, inclusion: { in: STATUSES }
  validate :records_belong_to_business

  scope :recent, -> { order(created_at: :desc) }

  def whatsapp_url
    WhatsApp::MessageBuilder.new(
      business: business,
      template_key: "referral_invite",
      customer: referrer_customer
    ).url(phone: referrer_customer.phone)
  end

  private
    def normalize_referred_phone
      self.referred_phone_e164 = PhoneNumber.normalize(referred_phone_e164) if referred_phone_e164.present?
      self.reward_description = reward_description.presence || business&.referral_reward_description
    end

    def records_belong_to_business
      errors.add(:referrer_customer, "no pertenece al negocio") if referrer_customer.present? && referrer_customer.business_id != business_id
      errors.add(:referred_customer, "no pertenece al negocio") if referred_customer.present? && referred_customer.business_id != business_id
    end
end
