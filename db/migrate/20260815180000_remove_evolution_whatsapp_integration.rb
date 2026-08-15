class RemoveEvolutionWhatsAppIntegration < ActiveRecord::Migration[8.1]
  NOTIFICATION_COLUMNS = %i[
    whatsapp_notifications_enabled
    whatsapp_notifications_phone
    whatsapp_opted_in_at
    whatsapp_opt_in_source
    whatsapp_opted_out_at
    whatsapp_notify_pending_bookings
    whatsapp_notify_deposit_proofs
    whatsapp_notify_cancellations
    whatsapp_notify_daily_summary
  ].freeze

  def up
    drop_table :incoming_whatsapp_events, if_exists: true
    remove_index :businesses, :whatsapp_notifications_enabled, if_exists: true
    remove_index :businesses, :whatsapp_notifications_phone, if_exists: true
    NOTIFICATION_COLUMNS.each { |column| remove_column :businesses, column, if_exists: true }
  end

  def down
    add_column :businesses, :whatsapp_notifications_enabled, :boolean, null: false, default: true
    add_column :businesses, :whatsapp_notifications_phone, :string
    add_column :businesses, :whatsapp_opted_in_at, :datetime
    add_column :businesses, :whatsapp_opt_in_source, :string
    add_column :businesses, :whatsapp_opted_out_at, :datetime
    add_column :businesses, :whatsapp_notify_pending_bookings, :boolean, null: false, default: true
    add_column :businesses, :whatsapp_notify_deposit_proofs, :boolean, null: false, default: true
    add_column :businesses, :whatsapp_notify_cancellations, :boolean, null: false, default: true
    add_column :businesses, :whatsapp_notify_daily_summary, :boolean, null: false, default: false
    add_index :businesses, :whatsapp_notifications_enabled
    add_index :businesses, :whatsapp_notifications_phone

    create_table :incoming_whatsapp_events do |t|
      t.references :business, foreign_key: true
      t.string :instance_name, null: false
      t.string :event_type, null: false
      t.string :sender
      t.text :message
      t.jsonb :payload, null: false, default: {}
      t.datetime :received_at, null: false

      t.timestamps
    end

    add_index :incoming_whatsapp_events, :created_at
    add_index :incoming_whatsapp_events, [ :instance_name, :event_type ]
    add_index :incoming_whatsapp_events, :sender
  end
end
