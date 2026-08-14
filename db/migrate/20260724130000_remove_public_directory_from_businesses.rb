class RemovePublicDirectoryFromBusinesses < ActiveRecord::Migration[8.1]
  def up
    remove_index :businesses, name: "idx_businesses_public_directory", if_exists: true
    remove_column :businesses, :public_directory_enabled, if_exists: true
  end

  def down
    add_column :businesses, :public_directory_enabled, :boolean, null: false, default: true
    add_index :businesses, [ :public_directory_enabled, :province, :city ], name: "idx_businesses_public_directory"
  end
end
