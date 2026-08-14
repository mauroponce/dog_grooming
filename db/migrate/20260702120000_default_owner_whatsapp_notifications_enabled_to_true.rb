class DefaultOwnerWhatsAppNotificationsEnabledToTrue < ActiveRecord::Migration[8.1]
  def up
    change_column_default :businesses, :whatsapp_notifications_enabled, from: false, to: true

    execute <<~SQL.squish
      UPDATE businesses
      SET
        whatsapp_notifications_enabled = TRUE,
        whatsapp_notifications_phone = COALESCE(
          NULLIF(whatsapp_notifications_phone, ''),
          NULLIF(whatsapp_phone, ''),
          NULLIF(contact_phone, ''),
          NULLIF(phone, '')
        ),
        whatsapp_opted_in_at = COALESCE(whatsapp_opted_in_at, updated_at, CURRENT_TIMESTAMP),
        whatsapp_opt_in_source = COALESCE(NULLIF(whatsapp_opt_in_source, ''), 'default_enabled'),
        updated_at = CURRENT_TIMESTAMP
      WHERE whatsapp_opted_out_at IS NULL
    SQL
  end

  def down
    change_column_default :businesses, :whatsapp_notifications_enabled, from: true, to: false
  end
end
