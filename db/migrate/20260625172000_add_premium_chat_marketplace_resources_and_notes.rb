class AddPremiumChatMarketplaceResourcesAndNotes < ActiveRecord::Migration[8.1]
  def change
    change_table :businesses, bulk: true do |t|
      t.string :plan, null: false, default: "basic"
      t.boolean :ai_chat_enabled, null: false, default: false
      t.text :ai_context
      t.string :mercado_pago_user_id
      t.string :mercado_pago_public_key
      t.text :mercado_pago_access_token_ciphertext
      t.text :mercado_pago_refresh_token_ciphertext
      t.datetime :mercado_pago_connected_at
    end

    change_table :services, bulk: true do |t|
      t.boolean :deposit_required, null: false, default: false
      t.integer :deposit_percentage, null: false, default: 0
    end

    create_table :bookable_resources do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :bookable_resources, [ :business_id, :name ], unique: true

    create_table :service_resources do |t|
      t.references :service, null: false, foreign_key: true
      t.references :bookable_resource, null: false, foreign_key: true

      t.timestamps
    end
    add_index :service_resources, [ :service_id, :bookable_resource_id ], unique: true

    change_table :appointments, bulk: true do |t|
      t.references :bookable_resource, foreign_key: true
      t.string :deposit_status, null: false, default: "not_required"
      t.integer :deposit_amount_cents, null: false, default: 0
      t.string :mercado_pago_preference_id
      t.text :mercado_pago_init_point
      t.string :mercado_pago_payment_id
    end
    add_index :appointments, :mercado_pago_preference_id
    add_index :appointments, :mercado_pago_payment_id

    create_table :client_notes do |t|
      t.references :business, null: false, foreign_key: true
      t.references :customer_profile, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :title
      t.string :note_type, null: false, default: "general"
      t.text :body, null: false

      t.timestamps
    end
    add_index :client_notes, [ :business_id, :customer_profile_id, :created_at ]
  end
end
