class AddDepositReviewedByToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_reference :appointments, :deposit_reviewed_by, foreign_key: { to_table: :users }
  end
end
