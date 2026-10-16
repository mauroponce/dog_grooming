class BookingIntent < ApplicationRecord
  STATUSES = %w[started contact_entered slot_selected pending_deposit completed abandoned expired].freeze

  belongs_to :business
  belongs_to :customer_profile, optional: true
  belongs_to :service, optional: true
  belongs_to :employee_membership, optional: true
  belongs_to :appointment, optional: true

  before_validation :normalize_phone
  before_validation :set_expiration

  validates :status, inclusion: { in: STATUSES }
  validate :records_belong_to_business

  scope :active, -> { where(status: %w[started contact_entered slot_selected pending_deposit]) }
  scope :recoverable, -> { where(status: %w[abandoned expired pending_deposit]).where.not(phone_e164: [ nil, "" ]) }
  scope :expired_for_recovery, -> { active.where("expires_at <= ?", Time.current) }
  scope :recent, -> { order(created_at: :desc) }

  STATUSES.each do |value|
    define_method("#{value}?") { status == value }
  end

  def mark_contact_entered!(full_name:, phone:, customer_profile: nil)
    update!(
      status: "contact_entered",
      full_name: full_name.presence || self.full_name,
      phone_e164: PhoneNumber.normalize(phone.presence || phone_e164),
      customer_profile: customer_profile || self.customer_profile
    )
  end

  def mark_slot_selected!(starts_at:, employee_membership: nil)
    update!(
      status: "slot_selected",
      selected_starts_at: starts_at,
      employee_membership: employee_membership || self.employee_membership
    )
  end

  def mark_completed!(appointment)
    update!(status: "completed", appointment:, completed_at: Time.current)
  end

  def expire_for_recovery!
    update!(status: "abandoned")
  end

  def customer_name
    customer_profile&.name.presence || full_name.presence || "clienta"
  end

  private
    def normalize_phone
      self.phone_e164 = PhoneNumber.normalize(phone_e164) if phone_e164.present?
    end

    def set_expiration
      self.expires_at ||= 2.hours.from_now unless completed?
    end

    def records_belong_to_business
      errors.add(:customer_profile, "no pertenece al negocio") if customer_profile.present? && customer_profile.business_id != business_id
      errors.add(:service, "no pertenece al negocio") if service.present? && service.business_id != business_id
      errors.add(:employee_membership, "no pertenece al negocio") if employee_membership.present? && employee_membership.business_id != business_id
      errors.add(:appointment, "no pertenece al negocio") if appointment.present? && appointment.business_id != business_id
    end
end
