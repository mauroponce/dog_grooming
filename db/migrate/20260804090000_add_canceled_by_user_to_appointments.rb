class AddCanceledByUserToAppointments < ActiveRecord::Migration[8.0]
  def change
    add_reference :appointments, :canceled_by_user, foreign_key: { to_table: :users }
  end
end
