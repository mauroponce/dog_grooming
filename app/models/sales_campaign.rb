class SalesCampaign < ApplicationRecord
  OBJECTIVES = %w[
    fill_gaps
    reactivate_customers
    promote_service
    sell_pack
    referrals
    abandoned_bookings
    waitlist_offer
  ].freeze
  STATUSES = %w[draft active completed archived].freeze

  belongs_to :business
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :service, optional: true
  belongs_to :campaign_link, optional: true
  has_many :sales_campaign_recipients, dependent: :destroy

  validates :name, :objective, :status, :message_template, presence: true
  validates :objective, inclusion: { in: OBJECTIVES }
  validates :status, inclusion: { in: STATUSES }
  validate :records_belong_to_business

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: "active") }

  def activate!
    update!(status: "active")
  end

  def completed!
    update!(status: "completed")
  end

  def recipient_count
    sales_campaign_recipients.size
  end

  private
    def records_belong_to_business
      errors.add(:service, "no pertenece al negocio") if service.present? && service.business_id != business_id
      errors.add(:campaign_link, "no pertenece al negocio") if campaign_link.present? && campaign_link.business_id != business_id
    end
end
