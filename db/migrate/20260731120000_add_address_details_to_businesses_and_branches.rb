class AddAddressDetailsToBusinessesAndBranches < ActiveRecord::Migration[8.0]
  def change
    add_column :businesses, :address_details, :string
    add_column :branches, :address_details, :string
  end
end
