class AddGeneralProfileFieldsToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :legal_name, :string
    add_column :businesses, :public_headline, :string
    add_column :businesses, :public_email, :string
    add_column :businesses, :instagram_url, :string
    add_column :businesses, :website_url, :string
  end
end
