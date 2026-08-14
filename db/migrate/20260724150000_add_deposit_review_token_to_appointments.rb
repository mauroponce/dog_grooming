class AddDepositReviewTokenToAppointments < ActiveRecord::Migration[8.0]
  class MigrationAppointment < ActiveRecord::Base
    self.table_name = "appointments"
  end

  def up
    add_column :appointments, :deposit_review_token, :string
    add_index :appointments, :deposit_review_token, unique: true

    say_with_time "Backfilling appointment deposit review tokens" do
      MigrationAppointment.reset_column_information
      MigrationAppointment.find_each do |appointment|
        appointment.update_columns(deposit_review_token: unique_token)
      end
    end

    change_column_null :appointments, :deposit_review_token, false
  end

  def down
    remove_index :appointments, :deposit_review_token
    remove_column :appointments, :deposit_review_token
  end

  private
    def unique_token
      loop do
        token = SecureRandom.urlsafe_base64(12)
        break token unless MigrationAppointment.exists?(deposit_review_token: token)
      end
    end
end
