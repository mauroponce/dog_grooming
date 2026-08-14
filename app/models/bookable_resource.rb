class BookableResource < ApplicationRecord
  RESOURCE_TYPES = {
    "cabin" => "Cabina",
    "machine" => "Máquina",
    "bed" => "Camilla",
    "table" => "Mesa",
    "space" => "Espacio",
    "other" => "Otro"
  }.freeze

  STATUSES = {
    "active" => "Activo",
    "inactive" => "Inactivo",
    "maintenance" => "Mantenimiento",
    "archived" => "Archivado"
  }.freeze

  belongs_to :business, touch: true
  belongs_to :branch, optional: true
  has_many :service_resources, dependent: :destroy
  has_many :services, through: :service_resources
  has_many :appointments, dependent: :nullify
  has_many :resource_blocks, dependent: :destroy
  has_many :availability_blocks, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :business_id }
  validates :resource_type, inclusion: { in: RESOURCE_TYPES.keys }
  validates :status, inclusion: { in: STATUSES.keys }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validate :branch_belongs_to_business

  before_validation :normalize_fields

  scope :active, -> { where(active: true, status: "active", archived_at: nil) }
  scope :visible, -> { where(archived_at: nil) }

  after_commit :broadcast_public_services_later, on: %i[create update destroy]

  def resource_type_label
    RESOURCE_TYPES.fetch(resource_type, "Recurso")
  end

  def status_label
    return "Archivado" if archived_at.present?

    STATUSES.fetch(status, "Activo")
  end

  def available_for_booking?
    active? && status == "active" && archived_at.blank?
  end

  def archived?
    archived_at.present? || status == "archived"
  end

  def archive!
    update!(active: false, status: "archived", archived_at: Time.current)
  end

  private
    def normalize_fields
      self.name = name.to_s.strip
      self.resource_type = resource_type.presence || "space"
      self.status = status.presence || "active"
      self.active = false if status.in?(%w[inactive archived])
      self.status = "inactive" if active == false && status != "archived"
      self.quantity = quantity.to_i.positive? ? quantity.to_i : 1
    end

    def branch_belongs_to_business
      return if branch.blank? || business.blank? || branch.business_id == business_id

      errors.add(:branch, "debe pertenecer al mismo negocio")
    end

    def broadcast_public_services_later
      PublicBooking::BroadcastServicesJob.perform_later(business_id)
    end
end
