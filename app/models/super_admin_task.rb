class SuperAdminTask < ApplicationRecord
  STATUSES = %w[pending completed dismissed].freeze
  TYPES = %w[send_billing_whatsapp review_subscription_payment call_overdue_customer].freeze

  belongs_to :business
  belongs_to :record, polymorphic: true, optional: true

  validates :task_type, :title, :status, presence: true
  validates :task_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :recent, -> { order(created_at: :desc) }

  def complete!
    update!(status: "completed", completed_at: Time.current)
  end
end
