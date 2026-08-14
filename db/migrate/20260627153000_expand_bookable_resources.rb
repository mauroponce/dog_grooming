class ExpandBookableResources < ActiveRecord::Migration[8.1]
  def change
    change_table :bookable_resources do |t|
      t.references :branch, foreign_key: true
      t.string :resource_type, null: false, default: "space"
      t.integer :quantity, null: false, default: 1
      t.string :status, null: false, default: "active"
      t.text :notes
      t.datetime :archived_at
    end

    add_index :bookable_resources, [ :business_id, :status, :resource_type ], name: "idx_bookable_resources_business_status_type"
    add_index :bookable_resources, [ :business_id, :archived_at ], name: "idx_bookable_resources_business_archived"

    add_column :service_resources, :quantity_required, :integer, null: false, default: 1

    create_table :resource_blocks do |t|
      t.references :business, null: false, foreign_key: true
      t.references :bookable_resource, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :reason, null: false, default: "maintenance"
      t.datetime :cancelled_at
      t.timestamps
    end

    add_index :resource_blocks, [ :business_id, :starts_at, :ends_at ], name: "idx_resource_blocks_business_range"
    add_index :resource_blocks, [ :bookable_resource_id, :starts_at, :ends_at ], name: "idx_resource_blocks_resource_range"
    add_index :resource_blocks, [ :bookable_resource_id, :cancelled_at ], name: "idx_resource_blocks_resource_cancelled"
  end
end
