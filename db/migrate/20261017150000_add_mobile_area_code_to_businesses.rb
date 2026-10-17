class AddMobileAreaCodeToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :mobile_area_code, :string, default: "11", null: false
  end
end
