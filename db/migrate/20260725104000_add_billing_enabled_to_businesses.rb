class AddBillingEnabledToBusinesses < ActiveRecord::Migration[8.0]
  def change
    add_column :businesses, :billing_enabled, :boolean, null: false, default: true
    add_index :businesses, :billing_enabled
  end
end
