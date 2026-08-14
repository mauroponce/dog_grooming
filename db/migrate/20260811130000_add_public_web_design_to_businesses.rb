class AddPublicWebDesignToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :public_site_mode, :string, null: false, default: "booking_link"
    add_column :businesses, :public_custom_css, :text

    add_index :businesses, :public_site_mode
  end
end
