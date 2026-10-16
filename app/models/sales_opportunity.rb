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

  private
    def records_belong_to_business
      errors.add(:customer_profile, "no pertenece al negocio") if customer_profile.present? && customer_profile.business_id != business_id
      errors.add(:service, "no pertenece al negocio") if service.present? && service.business_id != business_id
      errors.add(:appointment, "no pertenece al negocio") if appointment.present? && appointment.business_id != business_id
      errors.add(:employee_membership, "no pertenece al negocio") if employee_membership.present? && employee_membership.business_id != business_id
    end
end
