class CompleteWhatsAppCoexistenceConnections < ActiveRecord::Migration[8.1]
  def change
    change_table :whatsapp_connections, bulk: true do |t|
      t.datetime :connected_at
      t.datetime :verified_at
      t.datetime :subscribed_at
      t.datetime :token_expires_at
      t.datetime :data_access_expires_at
      t.datetime :authorization_failed_at
      t.boolean :automation_enabled, null: false, default: false
      t.jsonb :sync_metadata, null: false, default: {}
    end
    change_table :whatsapp_deliveries, bulk: true do |t|
      t.string :phone_number_id
      t.datetime :delivered_at
      t.datetime :read_at
      t.datetime :failed_at
      t.datetime :last_status_at
      t.jsonb :billing_metadata, null: false, default: {}
    end
    add_column :whatsapp_events, :phone_number_id, :string
    add_index :whatsapp_deliveries, [ :business_id, :phone_number_id, :created_at ], name: "idx_whatsapp_monthly_deliveries"
  end
end
