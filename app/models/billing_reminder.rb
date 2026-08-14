class BillingReminder < ApplicationRecord
  TYPES = %w[
    due_7_days due_3_days due_today overdue_2_days overdue_5_days overdue_10_days
    manual_whatsapp_task restricted_notice suspended_notice
  ].freeze

  belongs_to :business
  belongs_to :subscription_invoice

  validates :reminder_type, :sent_at, :channel, :recipient, :status, presence: true
  validates :reminder_type, inclusion: { in: TYPES }
  validates :reminder_type, uniqueness: { scope: [ :subscription_invoice_id, :channel ] }

  def sent?
    status == "sent"
  end
end
