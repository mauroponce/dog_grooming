class AddPostAppointmentHistory < ActiveRecord::Migration[8.1]
  def change
    add_reference :appointments, :completed_by, foreign_key: { to_table: :users }
    add_column :appointments, :completed_at, :datetime

    add_column :customer_profiles, :no_show_count, :integer, null: false, default: 0
    add_column :customer_profiles, :last_no_show_at, :datetime

    reversible do |dir|
      dir.up do
        remove_index :appointments, name: "idx_active_unassigned_appointments", if_exists: true
        remove_index :appointments, name: "idx_active_employee_appointments", if_exists: true
        add_index :appointments, [ :business_id, :starts_at ],
          name: "idx_active_unassigned_appointments",
          unique: true,
          where: "status NOT IN (2, 8, 9, 10, 11) AND employee_membership_id IS NULL"
        add_index :appointments, [ :employee_membership_id, :starts_at ],
          name: "idx_active_employee_appointments",
          unique: true,
          where: "status NOT IN (2, 8, 9, 10, 11) AND employee_membership_id IS NOT NULL"
      end

      dir.down do
        remove_index :appointments, name: "idx_active_unassigned_appointments", if_exists: true
        remove_index :appointments, name: "idx_active_employee_appointments", if_exists: true
        add_index :appointments, [ :business_id, :starts_at ],
          name: "idx_active_unassigned_appointments",
          unique: true,
          where: "status <> 2 AND employee_membership_id IS NULL"
        add_index :appointments, [ :employee_membership_id, :starts_at ],
          name: "idx_active_employee_appointments",
          unique: true,
          where: "status <> 2 AND employee_membership_id IS NOT NULL"
      end
    end

    create_table :booking_notes do |t|
      t.references :business, null: false, foreign_key: true
      t.references :appointment, null: false, foreign_key: true
      t.references :customer_profile, null: false, foreign_key: true
      t.references :employee_membership, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.text :body
      t.string :note_type, null: false
      t.datetime :follow_up_at

      t.timestamps
    end

    add_index :booking_notes, [ :business_id, :customer_profile_id, :created_at ], name: "idx_booking_notes_business_customer_created"
    add_index :booking_notes, [ :appointment_id, :note_type ], name: "idx_booking_notes_appointment_type"
    add_index :booking_notes, [ :business_id, :follow_up_at ], name: "idx_booking_notes_follow_up", where: "follow_up_at IS NOT NULL"

    create_table :booking_attachments do |t|
      t.references :business, null: false, foreign_key: true
      t.references :appointment, null: false, foreign_key: true
      t.references :customer_profile, null: false, foreign_key: true
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.string :attachment_type, null: false
      t.string :visibility, null: false, default: "internal"
      t.string :caption

      t.timestamps
    end

    add_index :booking_attachments, [ :business_id, :customer_profile_id, :created_at ], name: "idx_booking_attachments_business_customer_created"
    add_index :booking_attachments, [ :appointment_id, :attachment_type ], name: "idx_booking_attachments_appointment_type"
    add_index :booking_attachments, [ :business_id, :visibility ], name: "idx_booking_attachments_business_visibility"
  end
end
