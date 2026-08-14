class ResourceBlock < ApplicationRecord
  REASONS = {
    "maintenance" => "Mantenimiento",
    "cleaning" => "Limpieza",
    "internal_use" => "Uso interno",
    "repair" => "Reparación",
    "machine_absence" => "Ausencia de máquina",
    "other" => "Otro"
  }.freeze

  belongs_to :business
  belongs_to :bookable_resource, touch: true
  belongs_to :created_by, class_name: "User", optional: true

  before_validation :assign_business_from_resource

  validates :starts_at, :ends_at, presence: true
  validates :reason, inclusion: { in: REASONS.keys }
  validate :ends_after_start
  validate :resource_belongs_to_business

  scope :active, -> { where(cancelled_at: nil).where("ends_at > ?", Time.current) }
  scope :overlapping, ->(starts_at, ends_at) { where("starts_at < ? AND ends_at > ?", ends_at, starts_at) }

  after_commit :broadcast_changes_later, on: %i[create update destroy]

  def reason_label
    REASONS.fetch(reason, "Otro")
  end

  def cancelled?
    cancelled_at.present?
  end

  private
    def assign_business_from_resource
      self.business ||= bookable_resource&.business
    end

    def ends_after_start
      return if starts_at.blank? || ends_at.blank?

      errors.add(:ends_at, "debe ser posterior al inicio") if ends_at <= starts_at
    end

    def resource_belongs_to_business
      return if bookable_resource.blank? || business.blank? || bookable_resource.business_id == business_id

      errors.add(:bookable_resource, "debe pertenecer al mismo negocio")
    end

    def broadcast_changes_later
      PublicBooking::BroadcastServicesJob.perform_later(business_id)
    end
end
