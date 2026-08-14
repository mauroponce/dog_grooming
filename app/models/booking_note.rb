class BookingNote < ApplicationRecord
  NOTE_TYPES = %w[post_appointment no_show cancellation follow_up reschedule].freeze

  belongs_to :business
  belongs_to :appointment
  belongs_to :customer_profile
  belongs_to :employee_membership, optional: true
  belongs_to :created_by, class_name: "User"

  validates :note_type, inclusion: { in: NOTE_TYPES }
  validate :customer_belongs_to_business
  validate :appointment_belongs_to_business
  validate :employee_belongs_to_business
  validate :creator_belongs_to_business

  scope :recent_first, -> { order(created_at: :desc) }
  scope :post_appointment, -> { where(note_type: "post_appointment") }

  def post_appointment?
    note_type == "post_appointment"
  end

  private
    def customer_belongs_to_business
      return if customer_profile.blank? || business.blank? || customer_profile.business_id == business_id

      errors.add(:customer_profile, "no pertenece a este negocio")
    end

    def appointment_belongs_to_business
      return if appointment.blank? || business.blank? || appointment.business_id == business_id

      errors.add(:appointment, "no pertenece a este negocio")
    end

    def employee_belongs_to_business
      return if employee_membership.blank? || business.blank? || employee_membership.business_id == business_id

      errors.add(:employee_membership, "no pertenece a este negocio")
    end

    def creator_belongs_to_business
      return if created_by.blank? || business.blank?
      return if created_by.admin? && created_by.business&.id == business_id
      return if created_by.employee_membership_for(business).present?

      errors.add(:created_by, "no pertenece a este negocio")
    end
end
