class MakeBillingRemindersRetryable < ActiveRecord::Migration[8.0]
  def up
    add_column :billing_reminders, :event_on, :date
    add_column :billing_reminders, :enqueued_at, :datetime
    change_column_null :billing_reminders, :sent_at, true
    change_column_default :billing_reminders, :status, from: "sent", to: "pending"

    execute <<~SQL.squish
      UPDATE billing_reminders
      SET event_on = CASE reminder_type
        WHEN 'due_7_days' THEN DATE(sent_at) + 7
        WHEN 'due_4_days' THEN DATE(sent_at) + 4
        WHEN 'due_3_days' THEN DATE(sent_at) + 3
        WHEN 'due_2_days' THEN DATE(sent_at) + 2
        WHEN 'due_1_day' THEN DATE(sent_at) + 1
        WHEN 'due_today' THEN DATE(sent_at)
        WHEN 'overdue_2_days' THEN DATE(sent_at) - 2
        WHEN 'overdue_5_days' THEN DATE(sent_at) - 5
        WHEN 'overdue_10_days' THEN DATE(sent_at) - 10
        ELSE DATE(sent_at)
      END
    SQL

    change_column_null :billing_reminders, :event_on, false
    remove_index :billing_reminders, name: "idx_billing_reminders_uniqueness"
    add_index :billing_reminders,
      [ :subscription_invoice_id, :reminder_type, :channel, :recipient, :event_on ],
      unique: true,
      name: "idx_billing_reminders_event_uniqueness"
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Multiple historical reminders may now exist for the same invoice and type."
  end
end
