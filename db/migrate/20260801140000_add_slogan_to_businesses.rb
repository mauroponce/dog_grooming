class AddSloganToBusinesses < ActiveRecord::Migration[8.0]
  def change
    add_column :businesses, :slogan, :string
  end
end
