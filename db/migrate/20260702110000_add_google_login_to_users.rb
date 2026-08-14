class AddGoogleLoginToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :google_uid, :string
    add_column :users, :google_connected_at, :datetime
    add_column :users, :last_login_provider, :string

    add_index :users, :google_uid, unique: true
  end
end
