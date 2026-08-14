class AllowNullCustomerPhoneOnAppointments < ActiveRecord::Migration[8.0]
  def change
    change_column_null :appointments, :customer_phone, true
  end
end
