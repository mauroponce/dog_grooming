class AddManualSubscriptionBilling < ActiveRecord::Migration[8.1]
  def change
    change_column_default :subscriptions, :status, from: "trialing", to: "trialing"
    add_column :subscriptions, :plan_name, :string, null: false, default: "Plan HolaTurno"
    add_column :subscriptions, :amount_cents, :integer, null: false, default: 2_000_000
    add_column :subscriptions, :billing_period_months, :integer, null: false, default: 1
    add_column :subscriptions, :included_professionals_count, :integer, null: false, default: 3
    add_column :subscriptions, :extra_professional_amount_cents, :integer, null: false, default: 500_000
    add_column :subscriptions, :trial_started_on, :date
    add_column :subscriptions, :trial_ends_on, :date
    add_column :subscriptions, :paid_until, :date
    add_column :subscriptions, :current_period_start, :date
    add_column :subscriptions, :current_period_end, :date
    add_column :subscriptions, :next_due_on, :date
    add_column :subscriptions, :grace_ends_on, :date
    add_column :subscriptions, :restricted_at, :datetime
    add_column :subscriptions, :suspended_at, :datetime
    add_column :subscriptions, :cancelled_at, :datetime

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE subscriptions
          SET
            plan_name = 'Plan HolaTurno',
            amount_cents = 2000000,
            billing_period_months = 1,
            included_professionals_count = 3,
            extra_professional_amount_cents = 500000,
            trial_started_on = DATE(businesses.trial_started_at),
            trial_ends_on = DATE(businesses.trial_ends_at),
            paid_until = DATE(subscriptions.expires_at),
            current_period_end = DATE(subscriptions.expires_at),
            next_due_on = DATE(COALESCE(subscriptions.expires_at, businesses.trial_ends_at)),
            grace_ends_on = DATE(COALESCE(subscriptions.expires_at, businesses.trial_ends_at)) + INTERVAL '15 days'
          FROM businesses
          WHERE businesses.id = subscriptions.business_id
        SQL
        execute <<~SQL.squish
          UPDATE subscriptions
          SET status = CASE
            WHEN status IN ('authorized', 'active') THEN 'active'
            WHEN status IN ('payment_under_review') THEN 'pending_review'
            WHEN status IN ('payment_pending', 'past_due', 'pending', 'expired', 'failed') THEN 'overdue'
            WHEN status IN ('canceled', 'cancelled') THEN 'cancelled'
            ELSE status
          END
        SQL
      end
    end

    create_table :subscription_invoices do |t|
      t.references :business, null: false, foreign_key: true
      t.references :subscription, null: false, foreign_key: true
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.integer :billing_period_months, null: false, default: 1
      t.integer :amount_cents, null: false
      t.string :status, null: false, default: "open"
      t.date :due_on, null: false
      t.datetime :paid_at
      t.datetime :overdue_at
      t.datetime :restricted_at
      t.datetime :suspended_at
      t.string :reference_code, null: false
      t.text :notes
      t.timestamps
    end

    add_index :subscription_invoices, :reference_code, unique: true
    add_index :subscription_invoices, [ :business_id, :status ]
    add_index :subscription_invoices, [ :business_id, :due_on ]
    add_index :subscription_invoices, [ :subscription_id, :period_start, :period_end ], name: "idx_subscription_invoices_period"

    create_table :subscription_payment_proofs do |t|
      t.references :business, null: false, foreign_key: true
      t.references :subscription_invoice, null: false, foreign_key: true
      t.references :uploaded_by, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending_review"
      t.datetime :uploaded_at, null: false
      t.datetime :reviewed_at
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.text :rejection_reason
      t.datetime :replaced_at
      t.timestamps
    end

    add_index :subscription_payment_proofs, [ :business_id, :status ]
    add_index :subscription_payment_proofs, [ :subscription_invoice_id, :status ], name: "idx_subscription_payment_proofs_invoice_status"

    create_table :billing_reminders do |t|
      t.references :business, null: false, foreign_key: true
      t.references :subscription_invoice, null: false, foreign_key: true
      t.string :reminder_type, null: false
      t.datetime :sent_at, null: false
      t.string :channel, null: false, default: "email"
      t.string :recipient, null: false
      t.string :status, null: false, default: "sent"
      t.timestamps
    end

    add_index :billing_reminders, [ :subscription_invoice_id, :reminder_type, :channel ], unique: true, name: "idx_billing_reminders_uniqueness"
    add_index :billing_reminders, [ :business_id, :sent_at ]

    create_table :super_admin_tasks do |t|
      t.references :business, null: false, foreign_key: true
      t.string :task_type, null: false
      t.string :title, null: false
      t.text :body
      t.string :status, null: false, default: "pending"
      t.datetime :due_at
      t.datetime :completed_at
      t.string :record_type
      t.bigint :record_id
      t.timestamps
    end

    add_index :super_admin_tasks, [ :status, :due_at ]
    add_index :super_admin_tasks, [ :record_type, :record_id ]
    add_index :super_admin_tasks, [ :business_id, :task_type, :record_type, :record_id ], name: "idx_super_admin_tasks_uniqueness"
  end
end
