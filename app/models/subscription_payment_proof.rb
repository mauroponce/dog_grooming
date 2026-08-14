class SubscriptionPaymentProof < ApplicationRecord
  include PurgesReplacedAttachedBlobs

  STATUSES = %w[pending_review approved rejected replaced].freeze
  CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp application/pdf].freeze
  EXTENSIONS = %w[.jpg .jpeg .png .webp .pdf].freeze
  MAX_SIZE = 5.megabytes

  belongs_to :business
  belongs_to :subscription_invoice
  belongs_to :uploaded_by, class_name: "User", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_one_attached :file
  purge_replaced_attached_blobs_for :file

  validates :status, :uploaded_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :records_belong_to_business

  scope :pending_review, -> { where(status: "pending_review") }
  scope :recent, -> { order(uploaded_at: :desc, created_at: :desc) }

  def pending_review?
    status == "pending_review"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def replaced?
    status == "replaced"
  end

  private
    def records_belong_to_business
      errors.add(:subscription_invoice, "no pertenece al negocio") if subscription_invoice.present? && subscription_invoice.business_id != business_id
    end
end
