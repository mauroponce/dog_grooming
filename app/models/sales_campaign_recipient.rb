class SalesCampaignRecipient < ApplicationRecord
  STATUSES = %w[pending contacted dismissed booked].freeze

  belongs_to :business
  belongs_to :sales_campaign
  belongs_to :customer_profile
  belongs_to :converted_booking, class_name: "Appointment", optional: true

  before_validation :normalize_phone
  before_validation :render_message

  validates :phone_e164, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :customer_profile_id, uniqueness: { scope: :sales_campaign_id }
  validate :records_belong_to_business

  scope :pending, -> { where(status: "pending") }
  scope :actionable, -> { where(status: "pending") }

  def contacted!
    update!(status: "contacted", contacted_at: Time.current)
  end

  def dismiss!
    update!(status: "dismissed")
  end

  private
    def normalize_phone
      self.phone_e164 = PhoneNumber.normalize(phone_e164.presence || customer_profile&.phone)
    end

    def render_message
      return if sales_campaign.blank? || customer_profile.blank?

      self.rendered_message = Sales::TemplateRenderer.new(
        business: business || sales_campaign.business,
        template: sales_campaign.message_template,
        customer: customer_profile,
        service: sales_campaign.service,
        campaign_link: sales_campaign.campaign_link
      ).call
    end

    def records_belong_to_business
      errors.add(:sales_campaign, "no pertenece al negocio") if sales_campaign.present? && sales_campaign.business_id != business_id
      errors.add(:customer_profile, "no pertenece al negocio") if customer_profile.present? && customer_profile.business_id != business_id
      errors.add(:converted_booking, "no pertenece al negocio") if converted_booking.present? && converted_booking.business_id != business_id
    end
end
