class AddGroomingBookingConfiguration < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :plan_selected, :string, null: false, default: "basic"
    change_column_default :subscriptions, :amount_cents, from: 2_500_000, to: 3_500_000
    add_check_constraint :subscriptions, "plan_selected IN ('basic', 'pro')", name: "subscriptions_valid_plan"
    add_column :businesses, :simultaneous_capacity, :integer
    add_column :businesses, :arrival_mode, :string, default: "continuous", null: false
    add_column :businesses, :arrival_times, :jsonb, default: {}, null: false
    add_column :businesses, :whatsapp_reminder_hours, :integer, default: 24, null: false
    add_check_constraint :businesses, "simultaneous_capacity BETWEEN 1 AND 10", name: "businesses_valid_capacity"
    add_check_constraint :businesses, "arrival_mode IN ('fixed', 'continuous')", name: "businesses_valid_arrival_mode"
    add_check_constraint :businesses, "whatsapp_reminder_hours IN (2, 24)", name: "businesses_valid_reminder_hours"
    remove_index :appointments, [ :business_id, :starts_at ], name: "idx_active_unassigned_appointments", unique: true, where: "status NOT IN (2, 8, 9, 10, 11) AND employee_membership_id IS NULL"
    add_index :appointments, [ :business_id, :starts_at ], name: "idx_active_unassigned_appointments", where: "status NOT IN (2, 8, 9, 10, 11) AND employee_membership_id IS NULL"
    add_column :appointments, :payment_expires_at, :datetime

    create_table :whatsapp_connections do |t|
      t.references :business, null: false, foreign_key: true, index: { unique: true }
      t.string :phone_number_id, null: false
      t.string :waba_id, null: false
      t.text :access_token_ciphertext
      t.string :confirmation_template, default: "citapet_booking_confirmation", null: false
      t.string :reminder_template, default: "citapet_appointment_reminder", null: false
      t.string :template_language, default: "es_AR", null: false
      t.boolean :templates_approved, default: false, null: false
      t.datetime :disconnected_at
      t.timestamps
    end
    add_index :whatsapp_connections, :phone_number_id, unique: true
    create_table :whatsapp_contacts do |t|
      t.references :business, null: false, foreign_key: true
      t.string :phone, null: false
      t.string :name
      t.datetime :last_inbound_at
      t.datetime :paused_until
      t.datetime :last_human_at
      t.datetime :last_menu_at
      t.timestamps
    end
    add_index :whatsapp_contacts, [ :business_id, :phone ], unique: true
    create_table :whatsapp_events do |t|
      t.references :business, null: false, foreign_key: true
      t.string :provider_id, null: false
      t.string :kind, null: false
      t.jsonb :payload, default: {}, null: false
      t.datetime :processed_at
      t.timestamps
    end
    add_index :whatsapp_events, [ :business_id, :provider_id, :kind ], unique: true
    create_table :whatsapp_deliveries do |t|
      t.references :business, null: false, foreign_key: true
      t.references :appointment, foreign_key: true
      t.string :purpose, null: false
      t.string :dedupe_key, null: false
      t.string :status, default: "pending", null: false
      t.string :provider_id
      t.datetime :accepted_at
      t.datetime :sent_at
      t.boolean :trial_reminder, default: false, null: false
      t.jsonb :payload, default: {}, null: false
      t.timestamps
    end
    add_index :whatsapp_deliveries, :dedupe_key, unique: true
    add_index :whatsapp_deliveries, :provider_id, unique: true
    add_index :whatsapp_deliveries, [ :business_id, :trial_reminder, :status ], name: "idx_whatsapp_trial_usage"
  end
end
