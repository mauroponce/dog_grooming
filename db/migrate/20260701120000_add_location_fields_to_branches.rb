class AddLocationFieldsToBranches < ActiveRecord::Migration[8.1]
  def change
    add_column :branches, :province, :string
    add_column :branches, :neighborhood, :string
    add_column :branches, :postal_code, :string
    add_column :branches, :country, :string, default: "Argentina"
    add_column :branches, :latitude, :decimal, precision: 10, scale: 7
    add_column :branches, :longitude, :decimal, precision: 10, scale: 7
  end
end
