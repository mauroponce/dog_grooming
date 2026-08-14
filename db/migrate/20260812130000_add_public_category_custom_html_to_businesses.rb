class AddPublicCategoryCustomHtmlToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :public_category_custom_html, :text
  end
end
