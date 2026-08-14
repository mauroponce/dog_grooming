class AddTeamProfileAndAvailability < ActiveRecord::Migration[8.1]
  def change
    add_column :employee_memberships, :phone, :string
    add_column :employee_memberships, :specialty, :string
    add_column :employee_memberships, :sort_order, :integer, null: false, default: 0
    add_column :employee_memberships, :archived_at, :datetime
    add_index :employee_memberships, [ :business_id, :sort_order ]
    add_index :employee_memberships, [ :business_id, :archived_at ]

    create_table :employee_availability_rules do |t|
      t.references :employee_membership, null: false, foreign_key: true
      t.integer :weekday, null: false
      t.boolean :active, null: false, default: true
      t.time :start_time
      t.time :end_time
      t.timestamps
    end

    add_index :employee_availability_rules, [ :employee_membership_id, :weekday ], unique: true, name: "idx_employee_availability_weekday"
  end
end
