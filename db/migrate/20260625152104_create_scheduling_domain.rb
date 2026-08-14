class CreateSchedulingDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :businesses do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }, index: { unique: true }
      t.string :name, null: false
      t.string :slug, null: false
      t.string :contact_phone, null: false
      t.string :whatsapp_phone
      t.integer :cancellation_notice_hours, null: false, default: 12
      t.datetime :disabled_at
      t.datetime :trial_ends_at, null: false
      t.datetime :onboarding_completed_at

      t.timestamps
    end

    add_index :businesses, :slug, unique: true

    create_table :services do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :duration_minutes, null: false
      t.integer :price_cents, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :services, [ :business_id, :active ]

    create_table :availability_rules do |t|
      t.references :business, null: false, foreign_key: true
      t.integer :weekday, null: false
      t.boolean :active, null: false, default: false
      t.time :start_time
      t.time :end_time

      t.timestamps
    end

    add_index :availability_rules, [ :business_id, :weekday ], unique: true

    create_table :customer_profiles do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name
      t.string :phone, null: false
      t.string :normalized_phone, null: false
      t.string :email
      t.datetime :blocked_at
      t.text :blocked_reason
      t.integer :total_cancellations_count, null: false, default: 0
      t.integer :consecutive_late_cancellations_count, null: false, default: 0
      t.datetime :last_late_cancellation_at

      t.timestamps
    end

    add_index :customer_profiles, [ :business_id, :normalized_phone ], unique: true

    create_table :appointments do |t|
      t.references :business, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :customer_profile, foreign_key: true
      t.string :customer_name, null: false
      t.string :customer_phone, null: false
      t.string :customer_email
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :status, null: false, default: 0
      t.integer :source, null: false, default: 0
      t.text :notes
      t.datetime :confirmed_at
      t.datetime :canceled_at
      t.string :canceled_by
      t.text :cancellation_reason
      t.boolean :canceled_late, null: false, default: false
      t.datetime :reminder_sent_at

      t.timestamps
    end

    add_index :appointments, [ :business_id, :starts_at ]
    add_index :appointments, [ :business_id, :status ]
    add_index :appointments, [ :business_id, :starts_at ], unique: true, where: "status <> 2", name: "index_active_appointments_on_business_and_start"

    create_table :subscriptions do |t|
      t.references :business, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: "trialing"
      t.string :mercado_pago_preapproval_id
      t.text :mercado_pago_init_point
      t.text :mercado_pago_sandbox_init_point
      t.string :external_reference, null: false
      t.string :payer_email
      t.datetime :subscribed_at
      t.datetime :expires_at
      t.datetime :last_payment_at
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :subscriptions, :external_reference, unique: true
    add_index :subscriptions, :mercado_pago_preapproval_id, unique: true

    create_table :provider_events do |t|
      t.references :business, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :event_type, null: false
      t.string :title, null: false
      t.text :body
      t.jsonb :metadata, null: false, default: {}
      t.datetime :read_at

      t.timestamps
    end

    add_index :provider_events, [ :business_id, :event_type ]
    add_index :provider_events, [ :business_id, :read_at ]

    create_table :notification_deliveries do |t|
      t.references :business, null: false, foreign_key: true
      t.references :appointment, foreign_key: true
      t.string :channel, null: false
      t.string :recipient, null: false
      t.string :template, null: false
      t.string :status, null: false, default: "pending"
      t.string :provider_message_id
      t.text :error_message
      t.datetime :sent_at
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    add_index :notification_deliveries, [ :business_id, :channel, :status ]
  end
end
