class AddLocationFieldsToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :latitude, :decimal, precision: 10, scale: 7
    add_column :businesses, :longitude, :decimal, precision: 10, scale: 7
    add_column :businesses, :phone, :string
    add_index :businesses, [ :latitude, :longitude ]

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE businesses
          SET phone = contact_phone
          WHERE phone IS NULL
        SQL
      end
    end
  end
end
