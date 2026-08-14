class CreateCustomerReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_reminders do |t|
      t.references :business, null: false, foreign_key: true
      t.references :customer_profile, null: false, foreign_key: true
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.references :completed_by, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.datetime :remind_at, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :completed_at

      t.timestamps
    end

    add_index :customer_reminders, [ :business_id, :status, :remind_at ]
  end
end
