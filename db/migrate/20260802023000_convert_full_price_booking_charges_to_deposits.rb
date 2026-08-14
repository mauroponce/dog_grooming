class ConvertFullPriceBookingChargesToDeposits < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE appointments
      SET payment_charge_mode = 'deposit'
      WHERE payment_charge_mode = 'full_price'
    SQL
  end

  def down
    # The reservation flow no longer distinguishes full-price payments from deposits.
  end
end
