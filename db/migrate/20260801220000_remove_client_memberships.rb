class RemoveClientMemberships < ActiveRecord::Migration[8.0]
  def up
    remove_reference :appointments, :client_membership, foreign_key: true, index: true if column_exists?(:appointments, :client_membership_id)
    remove_column :appointments, :membership_credit_redeemed_at, :datetime if column_exists?(:appointments, :membership_credit_redeemed_at)

    drop_table :client_memberships, if_exists: true do |t|
      t.references :center, null: false, foreign_key: { to_table: :businesses }
      t.references :membership_plan, null: false, foreign_key: true
      t.string :client_phone, null: false
      t.string :normalized_phone, null: false
      t.string :payer_email
      t.string :status, null: false, default: "pending"
      t.integer :remaining_credits, null: false, default: 0
      t.datetime :last_payment_at
      t.timestamps
      t.index [ :center_id, :normalized_phone, :status ], name: "idx_client_memberships_lookup"
    end

    drop_table :membership_plans, if_exists: true do |t|
      t.references :center, null: false, foreign_key: { to_table: :businesses }
      t.string :name, null: false
      t.decimal :price, precision: 12, scale: 2, null: false
      t.string :frequency, null: false, default: "monthly"
      t.integer :credits_per_month, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index [ :center_id, :active ]
    end
  end

  def down
    create_table :membership_plans do |t|
      t.references :center, null: false, foreign_key: { to_table: :businesses }
      t.string :name, null: false
      t.decimal :price, precision: 12, scale: 2, null: false
      t.string :frequency, null: false, default: "monthly"
      t.integer :credits_per_month, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index [ :center_id, :active ]
    end

    create_table :client_memberships do |t|
      t.references :center, null: false, foreign_key: { to_table: :businesses }
      t.references :membership_plan, null: false, foreign_key: true
      t.string :client_phone, null: false
      t.string :normalized_phone, null: false
      t.string :payer_email
      t.string :status, null: false, default: "pending"
      t.integer :remaining_credits, null: false, default: 0
      t.datetime :last_payment_at
      t.timestamps
      t.index [ :center_id, :normalized_phone, :status ], name: "idx_client_memberships_lookup"
    end

    add_reference :appointments, :client_membership, foreign_key: true, index: true unless column_exists?(:appointments, :client_membership_id)
    add_column :appointments, :membership_credit_redeemed_at, :datetime unless column_exists?(:appointments, :membership_credit_redeemed_at)
  end
end
