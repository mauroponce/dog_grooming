class AddPaymentModesToServicesAndAppointments < ActiveRecord::Migration[8.0]
  def change
    add_column :services, :payment_collection_method, :string, null: false, default: "business_default"
    add_column :services, :payment_charge_mode, :string, null: false, default: "business_default"
    add_index :services, [ :business_id, :payment_collection_method ], name: "idx_services_business_payment_collection"

    add_column :appointments, :payment_collection_method, :string, null: false, default: "none"
    add_column :appointments, :payment_charge_mode, :string, null: false, default: "none"
    add_index :appointments, [ :business_id, :payment_collection_method, :starts_at ], name: "idx_appointments_payment_collection"
  end
end
