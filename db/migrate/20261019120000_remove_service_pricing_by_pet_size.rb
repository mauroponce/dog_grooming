class RemoveServicePricingByPetSize < ActiveRecord::Migration[8.1]
  def up
    remove_reference :appointments, :service_variant, foreign_key: true
    remove_column :appointments, :service_variant_name
    remove_column :appointments, :service_variant_price_cents
    remove_column :appointments, :service_variant_duration_minutes
    remove_reference :pets, :pet_size_band, foreign_key: true
    drop_table :service_variants
    drop_table :pet_size_bands
    remove_column :services, :pricing_mode
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Los precios por tamaño fueron eliminados sin preservar datos"
  end
end
