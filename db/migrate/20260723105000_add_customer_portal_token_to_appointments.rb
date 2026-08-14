class AddCustomerPortalTokenToAppointments < ActiveRecord::Migration[8.1]
  TOKEN_BYTES = 12

  def up
    add_column :appointments, :customer_portal_token, :string

    say_with_time "Backfilling appointment customer portal tokens" do
      Appointment.reset_column_information
      Appointment.find_each do |appointment|
        token = unique_token
        appointment.update_columns(customer_portal_token: token)
      end
    end

    change_column_null :appointments, :customer_portal_token, false
    add_index :appointments, :customer_portal_token, unique: true
  end

  def down
    remove_index :appointments, :customer_portal_token
    remove_column :appointments, :customer_portal_token
  end

  private
    def unique_token
      loop do
        token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
        return token unless Appointment.exists?(customer_portal_token: token)
      end
    end
end
