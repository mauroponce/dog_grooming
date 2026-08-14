class AddReschedulingNoticeHoursToBusinesses < ActiveRecord::Migration[8.0]
  def change
    add_column :businesses, :rescheduling_notice_hours, :integer, null: false, default: 24
  end
end
