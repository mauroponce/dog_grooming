class CustomerReminder < ApplicationRecord
  STATUSES = %w[pending resolved completed dismissed].freeze
  REMINDER_TYPES = %w[service_follow_up manual inactive_customer waitlist gap_opportunity].freeze

  belongs_to :business
  belongs_to :customer_profile
  belongs_to :service, optional: true
  belongs_to :appointment, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :completed_by, class_name: "User", optional: true

  validates :body, :remind_at, :status, :reminder_type, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :reminder_type, inclusion: { in: REMINDER_TYPES }
  validate :customer_belongs_to_business
  validate :service_belongs_to_business
  validate :appointment_belongs_to_business
  validate :assignee_belongs_to_business

  scope :pending, -> { where(status: "pending") }
  scope :due, -> { pending.where("remind_at <= ?", Time.current) }
  scope :recent_first, -> { order(Arel.sql("CASE status WHEN 'pending' THEN 0 ELSE 1 END"), remind_at: :asc, created_at: :desc) }

  def pending?
    status == "pending"
  end

  def resolved?
    status.in?(%w[resolved completed])
  end

  def dismissed?
    status == "dismissed"
  end

  def due?
    pending? && remind_at <= Time.current
  end

  def resolve!(actor:)
    update!(status: "resolved", completed_at: Time.current, completed_by: actor)
  end

  def dismiss!(actor: nil)
    update!(status: "dismissed", dismissed_at: Time.current, completed_by: actor)
  end

  private
    def customer_belongs_to_business
      return if customer_profile.blank? || business.blank? || customer_profile.business_id == business_id

      errors.add(:customer_profile, "no pertenece a este negocio")
    end

    def service_belongs_to_business
      return if service.blank? || business.blank? || service.business_id == business_id

      errors.add(:service, "no pertenece a este negocio")
    end

    def appointment_belongs_to_business
      return if appointment.blank? || business.blank? || appointment.business_id == business_id

      errors.add(:appointment, "no pertenece a este negocio")
    end

    def assignee_belongs_to_business
      return if assigned_to.blank? || business.blank?
      return if assigned_to.admin? && assigned_to.business&.id == business_id
      return if assigned_to.employee_membership_for(business).present?

      errors.add(:assigned_to, "no pertenece a este negocio")
    end
end
