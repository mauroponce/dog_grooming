require "ostruct"

class SalesOpportunity < ApplicationRecord
  TYPES = %w[
    follow_up_due
    inactive_customer
    fillable_gap
    waitlist_match
    abandoned_booking
    pack_ending
    referral_request
  ].freeze
  STATUSES = %w[open contacted dismissed converted expired].freeze

  belongs_to :business
  belongs_to :customer_profile, optional: true
  belongs_to :service, optional: true
  belongs_to :appointment, optional: true
  belongs_to :employee_membership, optional: true

  validates :opportunity_type, :title, :status, presence: true
  validates :opportunity_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :records_belong_to_business

  scope :open, -> { where(status: "open") }
  scope :recent, -> { order(score: :desc, due_at: :asc, created_at: :desc) }
  scope :due, -> { open.where("due_at IS NULL OR due_at <= ?", Time.current) }

  STATUSES.each do |value|
    define_method("#{value}?") { status == value }
  end

  def contacted!
    update!(status: "contacted", contacted_at: Time.current)
  end

  def dismiss!
    update!(status: "dismissed", dismissed_at: Time.current)
  end

  def converted!(appointment: nil)
    update!(status: "converted", converted_at: Time.current, appointment: appointment || self.appointment)
  end

  def priority_label
    return "Alta" if score >= 80
    return "Media" if score >= 50

    "Baja"
  end

  def whatsapp_template_key
    {
      "follow_up_due" => "sales_follow_up",
      "inactive_customer" => "inactive_customer_reactivation",
      "fillable_gap" => "gap_offer",
      "waitlist_match" => "waitlist_offer",
      "abandoned_booking" => "abandoned_booking_recovery",
      "pack_ending" => "pack_renewal",
      "referral_request" => "referral_invite"
    }.fetch(opportunity_type, "customer_reactivation")
  end

  def whatsapp_url
    phone = customer_profile&.phone.presence || appointment&.customer_phone.presence || metadata["phone_e164"].presence
    return "" if phone.blank?

    WhatsApp::MessageBuilder.new(
      business: business,
      template_key: whatsapp_template_key,
      booking: appointment,
      customer: customer_profile,
      service: service,
      professional: employee_membership,
      gap: gap_context,
      customer_pack: customer_pack_context,
      campaign_link: campaign_link_context
    ).url(phone: phone)
  end

  def gap_context
    starts_at = metadata["gap_starts_at"].presence
    return if starts_at.blank?

    OpenStruct.new(starts_at: Time.zone.parse(starts_at))
  rescue ArgumentError, TypeError
    nil
  end

  def customer_pack_context
    CustomerPack.find_by(id: metadata["customer_pack_id"], business: business) if metadata["customer_pack_id"].present?
  end

  def campaign_link_context
    CampaignLink.find_by(id: metadata["campaign_link_id"], business: business) if metadata["campaign_link_id"].present?
  end

  private
    def records_belong_to_business
      errors.add(:customer_profile, "no pertenece al negocio") if customer_profile.present? && customer_profile.business_id != business_id
      errors.add(:service, "no pertenece al negocio") if service.present? && service.business_id != business_id
      errors.add(:appointment, "no pertenece al negocio") if appointment.present? && appointment.business_id != business_id
      errors.add(:employee_membership, "no pertenece al negocio") if employee_membership.present? && employee_membership.business_id != business_id
    end
end
