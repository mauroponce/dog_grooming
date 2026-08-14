class AddPublicCustomHtmlToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :public_custom_html, :text
  end
end
