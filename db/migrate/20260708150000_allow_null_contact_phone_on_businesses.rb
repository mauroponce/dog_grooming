class AllowNullContactPhoneOnBusinesses < ActiveRecord::Migration[8.1]
  def change
    change_column_null :businesses, :contact_phone, true
  end
end
