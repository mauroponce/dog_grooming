class AddCustomerAndInternalNotesToAppointments < ActiveRecord::Migration[8.0]
  def up
    add_column :appointments, :customer_notes, :text
    add_column :appointments, :internal_notes, :text

    execute <<~SQL.squish
      UPDATE appointments
      SET customer_notes = notes
      WHERE source = 0
        AND notes IS NOT NULL
        AND notes <> ''
    SQL

    execute <<~SQL.squish
      UPDATE appointments
      SET internal_notes = notes
      WHERE source <> 0
        AND notes IS NOT NULL
        AND notes <> ''
    SQL
  end

  def down
    remove_column :appointments, :internal_notes
    remove_column :appointments, :customer_notes
  end
end
