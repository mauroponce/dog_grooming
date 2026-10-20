class BillingReminder < ApplicationRecord
  TYPES = %w[
    due_7_days due_4_days due_3_days due_2_days due_1_day due_today
    overdue_2_days overdue_3_days overdue_5_days overdue_10_days
    manual_contact_task restricted_notice suspended_notice
  ].freeze

  belongs_to :business
  belongs_to :subscription_invoice

  STATUSES = %w[pending failed skipped sent].freeze

  validates :reminder_type, :channel, :recipient, :status, :event_on, presence: true
  validates :reminder_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :reminder_type, uniqueness: { scope: [ :subscription_invoice_id, :channel, :recipient, :event_on ] }
  validates :sent_at, presence: true, if: :sent?

  def sent?
    status == "sent"
  end

  def failed?
    status == "failed"
  end
end
