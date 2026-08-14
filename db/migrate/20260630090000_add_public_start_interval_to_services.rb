class AddPublicStartIntervalToServices < ActiveRecord::Migration[8.1]
  def change
    add_column :services, :public_start_interval_minutes, :integer
  end
end
