class AddBranchesEmployeeMembershipsAndPunditPermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :branches do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address
      t.string :city
      t.string :phone
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :branches, [ :business_id, :name ], unique: true

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          INSERT INTO branches (business_id, name, address, city, phone, active, created_at, updated_at)
          SELECT id, 'Principal', address, city, contact_phone, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          FROM businesses
        SQL
      end
    end

    create_table :employee_memberships do |t|
      t.references :business, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :branch, foreign_key: true
      t.references :invited_by, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :permissions, null: false, default: {}
      t.string :invitation_token_digest
      t.datetime :invitation_sent_at
      t.datetime :invitation_accepted_at
      t.datetime :invitation_expires_at
      t.timestamps
    end
    add_index :employee_memberships, [ :business_id, :email_address ], unique: true
    add_index :employee_memberships, [ :business_id, :status ]
    add_index :employee_memberships, :invitation_token_digest

    remove_index :appointments, name: "index_active_appointments_on_business_and_start"
    add_reference :appointments, :branch, foreign_key: true
    add_reference :appointments, :employee_membership, foreign_key: true
    add_index :appointments, [ :business_id, :starts_at ], name: "idx_active_unassigned_appointments", unique: true, where: "status <> 2 AND employee_membership_id IS NULL"
    add_index :appointments, [ :employee_membership_id, :starts_at ], name: "idx_active_employee_appointments", unique: true, where: "status <> 2 AND employee_membership_id IS NOT NULL"
  end
end
