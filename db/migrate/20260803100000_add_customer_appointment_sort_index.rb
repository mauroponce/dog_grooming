class AddCustomerAppointmentSortIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :appointments,
      [ :business_id, :status, :customer_profile_id ],
      name: "idx_appointments_business_status_customer"
  end
end
