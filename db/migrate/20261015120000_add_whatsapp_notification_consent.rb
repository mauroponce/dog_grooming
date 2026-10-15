class AddWhatsAppNotificationConsent < ActiveRecord::Migration[8.1]
  def change
    add_column :whatsapp_contacts, :opted_in_at, :datetime
    add_column :whatsapp_deliveries, :attempts, :integer, default: 0, null: false
  end
end
