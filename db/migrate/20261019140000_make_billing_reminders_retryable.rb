class MakeBillingRemindersRetryable < ActiveRecord::Migration[8.0]
  def change
    add_column :billing_reminders, :event_on, :date, null: false
    add_column :billing_reminders, :enqueued_at, :datetime
    change_column_null :billing_reminders, :sent_at, true
    change_column_default :billing_reminders, :status, from: "sent", to: "pending"

    remove_index :billing_reminders,
      [ :subscription_invoice_id, :reminder_type, :channel ],
      unique: true,
      name: "idx_billing_reminders_uniqueness"
    add_index :billing_reminders,
      [ :subscription_invoice_id, :reminder_type, :channel, :recipient, :event_on ],
      unique: true,
      name: "idx_billing_reminders_event_uniqueness"
  end
end
