class AddDeletedAtToCustomerProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :customer_profiles, :deleted_at, :datetime
    add_index :customer_profiles, [ :business_id, :deleted_at ]
  end
end
