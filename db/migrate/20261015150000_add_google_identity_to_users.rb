class AddGoogleIdentityToUsers < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :password_digest, true
    add_column :users, :google_uid, :string
    add_column :users, :google_connected_at, :datetime
    add_index :users, :google_uid, unique: true
  end
end
