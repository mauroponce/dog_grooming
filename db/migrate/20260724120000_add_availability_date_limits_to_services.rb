class AddAvailabilityDateLimitsToServices < ActiveRecord::Migration[8.1]
  def change
    add_column :services, :limit_availability_by_date, :boolean, null: false, default: false
    add_column :services, :availability_starts_on, :date
    add_column :services, :availability_ends_on, :date
  end
end
