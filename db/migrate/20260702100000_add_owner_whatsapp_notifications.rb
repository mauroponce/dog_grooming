class AddOwnerWhatsAppNotifications < ActiveRecord::Migration[8.1]
  EMAIL_NOTIFICATION_COLUMNS = %i[
    email_new_booking
    email_booking_cancelled
    email_new_deposit_proof
    email_new_waitlist_entry
    email_daily_digest
    email_weekly_digest
    email_daily_sales_digest
    email_weekly_sales_digest
    email_campaign_summary
  ].freeze

  class MigrationBusiness < ActiveRecord::Base
    self.table_name = "businesses"
  end

  def up
    add_business_notification_columns
    create_incoming_whatsapp_events_table
    set_email_notifications_default(false)
    disable_existing_email_notifications
  end

  def down
    drop_table :incoming_whatsapp_events, if_exists: true

    remove_column :businesses, :whatsapp_notifications_enabled, if_exists: true
    remove_column :businesses, :whatsapp_notifications_phone, if_exists: true
    remove_column :businesses, :whatsapp_opted_in_at, if_exists: true
    remove_column :businesses, :whatsapp_opt_in_source, if_exists: true
    remove_column :businesses, :whatsapp_opted_out_at, if_exists: true
    remove_column :businesses, :whatsapp_notify_pending_bookings, if_exists: true
    remove_column :businesses, :whatsapp_notify_deposit_proofs, if_exists: true
    remove_column :businesses, :whatsapp_notify_cancellations, if_exists: true
    remove_column :businesses, :whatsapp_notify_daily_summary, if_exists: true
    remove_column :businesses, :email_new_booking, if_exists: true
    remove_column :businesses, :email_booking_cancelled, if_exists: true

    set_email_notifications_default(true)
  end

  private
    def add_business_notification_columns
      add_column :businesses, :whatsapp_notifications_enabled, :boolean, null: false, default: false unless column_exists?(:businesses, :whatsapp_notifications_enabled)
      add_column :businesses, :whatsapp_notifications_phone, :string unless column_exists?(:businesses, :whatsapp_notifications_phone)
      add_column :businesses, :whatsapp_opted_in_at, :datetime unless column_exists?(:businesses, :whatsapp_opted_in_at)
      add_column :businesses, :whatsapp_opt_in_source, :string unless column_exists?(:businesses, :whatsapp_opt_in_source)
      add_column :businesses, :whatsapp_opted_out_at, :datetime unless column_exists?(:businesses, :whatsapp_opted_out_at)
      add_column :businesses, :whatsapp_notify_pending_bookings, :boolean, null: false, default: true unless column_exists?(:businesses, :whatsapp_notify_pending_bookings)
      add_column :businesses, :whatsapp_notify_deposit_proofs, :boolean, null: false, default: true unless column_exists?(:businesses, :whatsapp_notify_deposit_proofs)
      add_column :businesses, :whatsapp_notify_cancellations, :boolean, null: false, default: true unless column_exists?(:businesses, :whatsapp_notify_cancellations)
      add_column :businesses, :whatsapp_notify_daily_summary, :boolean, null: false, default: false unless column_exists?(:businesses, :whatsapp_notify_daily_summary)
      add_column :businesses, :email_new_booking, :boolean, null: false, default: false unless column_exists?(:businesses, :email_new_booking)
      add_column :businesses, :email_booking_cancelled, :boolean, null: false, default: false unless column_exists?(:businesses, :email_booking_cancelled)

      add_index :businesses, :whatsapp_notifications_enabled unless index_exists?(:businesses, :whatsapp_notifications_enabled)
      add_index :businesses, :whatsapp_notifications_phone unless index_exists?(:businesses, :whatsapp_notifications_phone)
    end

    def create_incoming_whatsapp_events_table
      return if table_exists?(:incoming_whatsapp_events)

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

    def set_email_notifications_default(default)
      EMAIL_NOTIFICATION_COLUMNS.each do |column|
        change_column_default :businesses, column, default if column_exists?(:businesses, column)
      end
    end

    def disable_existing_email_notifications
      MigrationBusiness.reset_column_information
      updates = EMAIL_NOTIFICATION_COLUMNS.index_with(false).slice(*MigrationBusiness.column_names.map(&:to_sym))
      MigrationBusiness.update_all(updates) if updates.any?
    end
end
