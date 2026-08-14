class AddPaymentDetailsToAppointments < ActiveRecord::Migration[8.0]
  def change
    add_column :appointments, :deposit_payment_method, :string
    add_column :appointments, :remaining_balance_paid_at, :datetime
    add_column :appointments, :remaining_balance_paid_cents, :integer, default: 0, null: false
    add_column :appointments, :remaining_balance_payment_method, :string
    add_reference :appointments, :remaining_balance_paid_by, foreign_key: { to_table: :users }
  end
end
