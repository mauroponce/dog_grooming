class AddAdvancedBookingFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :waitlist_entries do |t|
      t.references :center, null: false, foreign_key: { to_table: :businesses }
      t.references :service, null: false, foreign_key: true
      t.string :client_name, null: false
      t.string :client_phone, null: false
      t.date :desired_date, null: false
      t.string :status, null: false, default: "pending"
      t.string :token_seguro
      t.datetime :released_starts_at
      t.bigint :released_appointment_id
      t.datetime :notified_at
      t.datetime :expires_at

      t.timestamps
    end
    add_index :waitlist_entries, [ :center_id, :service_id, :desired_date, :status ], name: "idx_waitlist_lookup"
    add_index :waitlist_entries, :released_appointment_id
    add_index :waitlist_entries, :token_seguro

    create_table :dynamic_pricing_rules do |t|
      t.references :center, null: false, foreign_key: { to_table: :businesses }
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.decimal :discount_percentage, precision: 5, scale: 2, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :dynamic_pricing_rules, [ :center_id, :day_of_week, :active ], name: "idx_dynamic_pricing_lookup"

    create_table :membership_plans do |t|
      t.references :center, null: false, foreign_key: { to_table: :businesses }
      t.string :name, null: false
      t.decimal :price, precision: 12, scale: 2, null: false
      t.string :frequency, null: false, default: "monthly"
      t.integer :credits_per_month, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :membership_plans, [ :center_id, :active ]

    create_table :client_memberships do |t|
      t.references :center, null: false, foreign_key: { to_table: :businesses }
      t.references :membership_plan, null: false, foreign_key: true
      t.string :client_phone, null: false
      t.string :normalized_phone, null: false
      t.string :status, null: false, default: "pending"
      t.integer :remaining_credits, null: false, default: 0
      t.string :mp_preapproval_id
      t.text :mercado_pago_init_point
      t.string :payer_email
      t.datetime :last_payment_at

      t.timestamps
    end
    add_index :client_memberships, [ :center_id, :normalized_phone, :status ], name: "idx_client_memberships_lookup"
    add_index :client_memberships, :mp_preapproval_id, unique: true

    create_table :service_recommendations do |t|
      t.references :service, null: false, foreign_key: true
      t.references :recommended_service, null: false, foreign_key: { to_table: :services }

      t.timestamps
    end
    add_index :service_recommendations, [ :service_id, :recommended_service_id ], unique: true, name: "idx_service_recommendations_unique"

    create_table :appointment_addons do |t|
      t.references :appointment, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.integer :price_cents, null: false, default: 0

      t.timestamps
    end

    change_table :appointments, bulk: true do |t|
      t.integer :base_price_cents, null: false, default: 0
      t.integer :final_price_cents, null: false, default: 0
      t.decimal :discount_percentage, precision: 5, scale: 2, null: false, default: 0
      t.references :client_membership, foreign_key: true
      t.references :waitlist_entry, foreign_key: true
      t.datetime :membership_credit_redeemed_at
    end
  end
end
