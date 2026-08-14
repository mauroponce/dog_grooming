class CustomerPack < ApplicationRecord
  STATUSES = %w[active completed expired cancelled].freeze

  belongs_to :business
  belongs_to :customer_profile
  belongs_to :service_pack
  has_many :pack_sessions, dependent: :destroy

  before_validation :set_defaults

  validates :purchased_at, :status, :total_sessions, :remaining_sessions, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :total_sessions, numericality: { only_integer: true, greater_than: 0 }
  validates :used_sessions, :remaining_sessions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :records_belong_to_business
  validate :used_sessions_within_total

  scope :active, -> { where(status: "active") }
  scope :ending_soon, -> { active.where("remaining_sessions <= 1") }
  scope :recent, -> { order(created_at: :desc) }

  def consume_session!(appointment:, actor: nil, notes: nil)
    with_lock do
      raise "El pack no está activo" unless status == "active"
      raise "El pack no tiene sesiones disponibles" if remaining_sessions <= 0

      pack_sessions.create!(
        business: business,
        appointment: appointment,
        created_by: actor,
        used_at: Time.current,
        notes: notes
      )
      update!(
        used_sessions: used_sessions + 1,
        remaining_sessions: remaining_sessions - 1,
        status: remaining_sessions - 1 <= 0 ? "completed" : status
      )
    end
  end

  def compatible_with?(service)
    service_pack.service_id.blank? || service_pack.service_id == service&.id
  end

  private
    def set_defaults
      self.purchased_at ||= Time.current
      self.status ||= "active"
      self.total_sessions ||= service_pack&.sessions_count
      self.used_sessions ||= 0
      self.remaining_sessions = [ total_sessions.to_i - used_sessions.to_i, 0 ].max if total_sessions.present?
    end

    def records_belong_to_business
      errors.add(:customer_profile, "no pertenece al negocio") if customer_profile.present? && customer_profile.business_id != business_id
      errors.add(:service_pack, "no pertenece al negocio") if service_pack.present? && service_pack.business_id != business_id
    end

    def used_sessions_within_total
      return if used_sessions.to_i <= total_sessions.to_i

      errors.add(:used_sessions, "no puede superar el total de sesiones")
    end
end
