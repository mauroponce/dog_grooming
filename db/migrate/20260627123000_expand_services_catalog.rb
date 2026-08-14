class ExpandServicesCatalog < ActiveRecord::Migration[8.1]
  def change
    add_column :services, :visibility_mode, :string, null: false, default: "public"
    add_column :services, :sort_order, :integer, null: false, default: 0
    add_column :services, :popular, :boolean, null: false, default: false
    add_column :services, :archived_at, :datetime
    add_column :services, :deposit_amount_cents, :integer, null: false, default: 0
    add_column :services, :deposit_payment_deadline_minutes, :integer, null: false, default: 30
    add_column :services, :external_payment_link, :text

    add_index :services, [ :business_id, :visibility_mode ]
    add_index :services, [ :business_id, :sort_order ]
    add_index :services, [ :business_id, :archived_at ]

    create_table :service_professionals do |t|
      t.references :service, null: false, foreign_key: true
      t.references :employee_membership, null: false, foreign_key: true

      t.timestamps
    end

    add_index :service_professionals, [ :service_id, :employee_membership_id ], unique: true, name: "idx_service_professionals_unique"

    create_table :service_tags do |t|
      t.references :service, null: false, foreign_key: true
      t.string :name, null: false
      t.string :tag_type, null: false, default: "keyword"

      t.timestamps
    end

    add_index :service_tags, [ :service_id, :name, :tag_type ], unique: true
    add_index :service_tags, :name
  end
end
