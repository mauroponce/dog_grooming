class AddShortUuidToAppointments < ActiveRecord::Migration[8.0]
  TOKEN_BYTES = 9

  class MigrationAppointment < ApplicationRecord
    self.table_name = "appointments"
  end

  def up
    add_column :appointments, :short_uuid, :string

    MigrationAppointment.reset_column_information
    MigrationAppointment.where(short_uuid: [ nil, "" ]).find_each do |appointment|
      appointment.update_columns(short_uuid: unique_short_uuid)
    end

    change_column_null :appointments, :short_uuid, false
    add_index :appointments, :short_uuid, unique: true
  end

  def down
    remove_index :appointments, :short_uuid
    remove_column :appointments, :short_uuid
  end

  private
    def unique_short_uuid
      loop do
        token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
        break token unless MigrationAppointment.exists?(short_uuid: token)
      end
    end
end
