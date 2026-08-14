class RemovePaymentModesFromServices < ActiveRecord::Migration[8.1]
  def change
    remove_index :services, name: "idx_services_business_payment_collection"
    remove_column :services, :payment_collection_method, :string, null: false, default: "business_default"
    remove_column :services, :payment_charge_mode, :string, null: false, default: "business_default"
  end
end
