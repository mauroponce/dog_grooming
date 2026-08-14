class AddProfileFieldsToCustomerProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :customer_profiles, :first_name, :string
    add_column :customer_profiles, :last_name, :string
    add_column :customer_profiles, :birth_date, :date
    add_column :customer_profiles, :gender, :string
    add_index :customer_profiles, [ :business_id, :last_name, :first_name ], name: "index_customer_profiles_on_business_and_name_parts"

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE customer_profiles
          SET
            first_name = NULLIF(split_part(name, ' ', 1), ''),
            last_name = NULLIF(btrim(regexp_replace(name, '^\\S+\\s*', '')), '')
          WHERE name IS NOT NULL AND name <> ''
        SQL
      end
    end
  end
end
