class RenameWhatsAppIdToCiphertextOnWhatsAppContacts < ActiveRecord::Migration[8.1]
  def change
    rename_column :whatsapp_contacts, :whatsapp_id, :whatsapp_id_ciphertext
    change_column :whatsapp_contacts, :whatsapp_id_ciphertext, :text
  end
end
