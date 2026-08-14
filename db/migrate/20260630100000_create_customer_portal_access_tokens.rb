class CreateCustomerPortalAccessTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :customer_profiles, :normalized_email, :string
    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE customer_profiles
          SET normalized_email = LOWER(TRIM(email))
          WHERE email IS NOT NULL AND TRIM(email) <> ''
        SQL
      end
    end
    add_index :customer_profiles, [ :business_id, :normalized_email ], name: "idx_customer_profiles_business_email"

    create_table :customer_portal_access_tokens do |t|
      t.references :business, null: false, foreign_key: true
      t.references :customer_profile, foreign_key: true
      t.string :email, null: false
      t.string :token_digest, null: false
      t.string :purpose, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.datetime :last_sent_at
      t.string :request_ip
      t.text :request_user_agent
      t.timestamps
    end

    add_index :customer_portal_access_tokens, :token_digest, unique: true
    add_index :customer_portal_access_tokens, [ :business_id, :email ]
    add_index :customer_portal_access_tokens, :expires_at
  end
end
