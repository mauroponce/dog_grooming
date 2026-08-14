class AddVerticalGrowthFeatures < ActiveRecord::Migration[8.1]
  def change
    change_table :businesses, bulk: true do |t|
      t.boolean :email_new_deposit_proof, null: false, default: true
      t.boolean :email_new_waitlist_entry, null: false, default: true
      t.boolean :email_daily_digest, null: false, default: true
      t.boolean :email_weekly_digest, null: false, default: true
    end

    change_table :services, bulk: true do |t|
      t.boolean :follow_up_enabled, null: false, default: false
      t.integer :recommended_follow_up_days
    end
    add_index :services, [ :business_id, :follow_up_enabled ], name: "idx_services_business_follow_up"

    change_table :appointments, bulk: true do |t|
      t.datetime :no_show_at
    end

    change_table :customer_reminders, bulk: true do |t|
      t.references :service, foreign_key: true
      t.references :appointment, foreign_key: true
      t.string :reminder_type, null: false, default: "manual"
      t.datetime :dismissed_at
    end
    add_index :customer_reminders,
      [ :business_id, :customer_profile_id, :service_id, :reminder_type, :status ],
      name: "idx_customer_reminders_dedupe"

    change_table :waitlist_entries, bulk: true do |t|
      t.references :customer_profile, foreign_key: true
      t.references :employee_membership, foreign_key: true
      t.string :phone_e164
      t.string :email
      t.jsonb :preferred_weekdays, null: false, default: []
      t.jsonb :preferred_time_windows, null: false, default: []
      t.text :notes
      t.string :source, null: false, default: "public_page"
      t.datetime :offered_at
      t.datetime :accepted_at
      t.datetime :dismissed_at
    end
    add_index :waitlist_entries, [ :center_id, :status, :created_at ], name: "idx_waitlist_center_status_created"
    add_index :waitlist_entries, [ :center_id, :customer_profile_id ], name: "idx_waitlist_center_customer"

    create_table :whatsapp_templates do |t|
      t.references :business, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.text :body, null: false
      t.boolean :active, null: false, default: true
      t.boolean :system_default, null: false, default: true

      t.timestamps
    end
    add_index :whatsapp_templates, [ :business_id, :key ], unique: true

    create_table :email_delivery_logs do |t|
      t.references :business, foreign_key: true
      t.string :recipient, null: false
      t.string :mailer, null: false
      t.string :action, null: false
      t.string :subject, null: false
      t.string :provider, null: false, default: "resend"
      t.string :provider_message_id
      t.string :status, null: false
      t.datetime :sent_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :email_delivery_logs, [ :business_id, :created_at ], name: "idx_email_delivery_logs_business_created"
    add_index :email_delivery_logs, [ :mailer, :action, :status ], name: "idx_email_delivery_logs_mailer_status"
  end
end
