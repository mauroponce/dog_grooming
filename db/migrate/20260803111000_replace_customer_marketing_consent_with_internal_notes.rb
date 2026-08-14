class ReplaceCustomerMarketingConsentWithInternalNotes < ActiveRecord::Migration[8.0]
  def change
    remove_column :appointments, :customer_marketing_consent, :boolean, default: false, null: false
    remove_column :customer_profiles, :marketing_consent, :boolean, default: false, null: false
    add_column :customer_profiles, :internal_notes, :text
  end
end
