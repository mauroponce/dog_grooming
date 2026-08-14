class DefaultPublicPageToDirectBooking < ActiveRecord::Migration[8.1]
  def up
    change_column_default :businesses, :public_landing_enabled, from: true, to: false
    update "UPDATE businesses SET public_landing_enabled = FALSE"
  end

  def down
    change_column_default :businesses, :public_landing_enabled, from: false, to: true
  end
end
