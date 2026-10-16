class RemoveWhatsappIntegration < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE sales_campaign_recipients SET status = 'contacted' WHERE status = 'opened_whatsapp'"
    execute "UPDATE billing_reminders SET reminder_type = 'manual_contact_task' WHERE reminder_type = 'manual_whatsapp_task'"
    execute "UPDATE super_admin_tasks SET task_type = 'send_billing_contact' WHERE task_type = 'send_billing_whatsapp'"
    execute "UPDATE content_templates SET body = REPLACE(body, '{{business_whatsapp_url}}', '{{business_phone_url}}')"

    drop_table :whatsapp_deliveries, if_exists: true
    drop_table :whatsapp_events, if_exists: true
    drop_table :whatsapp_contacts, if_exists: true
    drop_table :whatsapp_connections, if_exists: true
    drop_table :whatsapp_templates, if_exists: true

    remove_check_constraint :businesses, name: "businesses_valid_reminder_hours", if_exists: true
    remove_column :businesses, :whatsapp_reminder_hours, if_exists: true
    remove_column :businesses, :whatsapp_phone, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "La integración y sus datos de WhatsApp fueron eliminados deliberadamente."
  end
end
