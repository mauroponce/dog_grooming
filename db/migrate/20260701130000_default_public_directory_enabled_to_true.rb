class DefaultPublicDirectoryEnabledToTrue < ActiveRecord::Migration[8.1]
  class MigrationBusiness < ActiveRecord::Base
    self.table_name = "businesses"
  end

  def up
    change_column_default :businesses, :public_directory_enabled, from: false, to: true
    MigrationBusiness.where(public_directory_enabled: false).update_all(public_directory_enabled: true, updated_at: Time.current)
  end

  def down
    change_column_default :businesses, :public_directory_enabled, from: true, to: false
  end
end
