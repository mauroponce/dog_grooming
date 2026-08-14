class AddCanReceiveAppointmentsToEmployeeMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :employee_memberships, :can_receive_appointments, :boolean, null: false, default: true
    add_index :employee_memberships,
      [ :business_id, :status, :archived_at, :can_receive_appointments ],
      name: "idx_employee_memberships_on_booking_enabled"
  end
end
