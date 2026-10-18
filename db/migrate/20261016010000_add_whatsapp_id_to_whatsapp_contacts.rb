class AddWhatsappIdToWhatsappContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :whatsapp_contacts, :whatsapp_id, :string
  end
end
