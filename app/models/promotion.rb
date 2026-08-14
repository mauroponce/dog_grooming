class Promotion < ApplicationRecord
  TYPES = %w[fill_gap combo pack_offer gift_card seasonal referral].freeze
  STATUSES = %w[draft active completed archived].freeze

  belongs_to :business
  belongs_to :service, optional: true
  belongs_to :campaign_link, optional: true

  validates :name, :promotion_type, :starts_at, :ends_at, :status, presence: true
  validates :promotion_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validate :records_belong_to_business
  validate :ends_after_start

  scope :active, -> { where(status: "active").where("starts_at <= ? AND ends_at >= ?", Time.current, Time.current) }
  scope :recent, -> { order(starts_at: :desc, created_at: :desc) }
  scope :upcoming, -> { where(status: %w[draft active]).where("ends_at >= ?", Time.current).order(:starts_at) }

  STATUSES.each do |value|
    define_method("#{value}?") { status == value }
  end

  def activate!
    update!(status: "active")
  end

  def archive!
    update!(status: "archived")
  end

  def copy_text
    lines = [ name ]
    lines << description if description.present?
    lines << "Reservá acá: #{campaign_link&.tracked_url || business.public_url}"
    lines.join("\n\n")
  end

  private
    def records_belong_to_business
      errors.add(:service, "no pertenece al negocio") if service.present? && service.business_id != business_id
      errors.add(:campaign_link, "no pertenece al negocio") if campaign_link.present? && campaign_link.business_id != business_id
    end

    def ends_after_start
      return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

      errors.add(:ends_at, "debe ser posterior al inicio")
    end
end
