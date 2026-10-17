class RemoveAiCustomerPortalAndWaitlist < ActiveRecord::Migration[8.1]
  def up
    remove_reference :appointments, :waitlist_entry, foreign_key: true if column_exists?(:appointments, :waitlist_entry_id)
    remove_column :appointments, :customer_portal_token if column_exists?(:appointments, :customer_portal_token)
    remove_column :customer_profiles, :customer_portal_token if column_exists?(:customer_profiles, :customer_portal_token)
    remove_column :customer_profiles, :customer_portal_short_token if column_exists?(:customer_profiles, :customer_portal_short_token)
    remove_column :businesses, :ai_chat_enabled if column_exists?(:businesses, :ai_chat_enabled)
    remove_column :businesses, :ai_context if column_exists?(:businesses, :ai_context)

    drop_table :customer_portal_access_tokens, if_exists: true
    drop_table :waitlist_entries, if_exists: true
    drop_table :ai_chat_messages, if_exists: true
    drop_table :ai_chat_conversations, if_exists: true
    drop_table :ai_context_imports, if_exists: true
    drop_table :ai_api_usage_events, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Los datos de IA, portal y lista de espera fueron eliminados."
  end
end
