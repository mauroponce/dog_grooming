class ExpandAvailabilityModel < ActiveRecord::Migration[8.1]
  def change
    add_column :availability_rules, :break_start_time, :time
    add_column :availability_rules, :break_end_time, :time

    add_column :employee_availability_rules, :break_start_time, :time
    add_column :employee_availability_rules, :break_end_time, :time
    add_column :employee_availability_rules, :inherits_business_hours, :boolean, null: false, default: true

    add_column :services, :professional_selection_mode, :string, null: false, default: "optional"
    add_column :services, :use_advanced_availability, :boolean, null: false, default: false
    add_index :services, [ :business_id, :professional_selection_mode ], name: "idx_services_business_professional_mode"

    create_table :availability_blocks do |t|
      t.references :business, null: false, foreign_key: true
      t.references :employee_membership, foreign_key: true
      t.references :bookable_resource, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :block_type, null: false, default: "center_block"
      t.string :reason
      t.datetime :cancelled_at
      t.timestamps
    end

    add_index :availability_blocks, [ :business_id, :starts_at, :ends_at ], name: "idx_availability_blocks_business_range"
    add_index :availability_blocks, [ :employee_membership_id, :starts_at, :ends_at ], name: "idx_availability_blocks_employee_range"
    add_index :availability_blocks, [ :bookable_resource_id, :starts_at, :ends_at ], name: "idx_availability_blocks_resource_range"
    add_index :availability_blocks, [ :business_id, :block_type, :cancelled_at ], name: "idx_availability_blocks_type"

    create_table :holidays do |t|
      t.references :business, null: false, foreign_key: true
      t.date :date, null: false
      t.string :name, null: false
      t.boolean :closed, null: false, default: true
      t.timestamps
    end

    add_index :holidays, [ :business_id, :date ], unique: true

    create_table :service_availability_rules do |t|
      t.references :service, null: false, foreign_key: true
      t.integer :weekday, null: false
      t.time :start_time
      t.time :end_time
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :service_availability_rules, [ :service_id, :weekday ], name: "idx_service_availability_rules_weekday"
  end
end
