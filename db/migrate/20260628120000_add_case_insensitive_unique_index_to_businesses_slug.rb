class AddCaseInsensitiveUniqueIndexToBusinessesSlug < ActiveRecord::Migration[8.1]
  def change
    remove_index :businesses, name: "index_businesses_on_slug", if_exists: true
    add_index :businesses, "lower(slug)", unique: true, name: "index_businesses_on_lower_slug"
  end
end
