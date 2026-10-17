class AddPetSizeBandsAndServiceVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :services, :pricing_mode, :string, null: false, default: "fixed"

    create_table :pet_size_bands do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :minimum_weight_kg, precision: 6, scale: 2, null: false, default: 0
      t.decimal :maximum_weight_kg, precision: 6, scale: 2
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :pet_size_bands, [ :business_id, :position ], unique: true
    add_index :pet_size_bands, [ :business_id, :name ], unique: true

    create_table :service_variants do |t|
      t.references :service, null: false, foreign_key: true
      t.references :pet_size_band, null: false, foreign_key: true
      t.integer :price_cents, null: false
      t.integer :duration_minutes, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :service_variants, [ :service_id, :pet_size_band_id ], unique: true

    add_reference :pets, :pet_size_band, foreign_key: true
    add_reference :appointments, :service_variant, foreign_key: true
    add_column :appointments, :service_variant_name, :string
    add_column :appointments, :service_variant_price_cents, :integer
    add_column :appointments, :service_variant_duration_minutes, :integer
  end
end
