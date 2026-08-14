class AddSidebarCounterCachesToBusinesses < ActiveRecord::Migration[8.0]
  def change
    add_column :businesses, :services_count, :integer, null: false, default: 0
    add_column :businesses, :employee_memberships_count, :integer, null: false, default: 0
    add_column :businesses, :customer_profiles_count, :integer, null: false, default: 0

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE businesses
          SET services_count = counts.records_count
          FROM (
            SELECT business_id, COUNT(*)::integer AS records_count
            FROM services
            GROUP BY business_id
          ) counts
          WHERE businesses.id = counts.business_id
        SQL

        execute <<~SQL.squish
          UPDATE businesses
          SET employee_memberships_count = counts.records_count
          FROM (
            SELECT business_id, COUNT(*)::integer AS records_count
            FROM employee_memberships
            GROUP BY business_id
          ) counts
          WHERE businesses.id = counts.business_id
        SQL

        execute <<~SQL.squish
          UPDATE businesses
          SET customer_profiles_count = counts.records_count
          FROM (
            SELECT business_id, COUNT(*)::integer AS records_count
            FROM customer_profiles
            GROUP BY business_id
          ) counts
          WHERE businesses.id = counts.business_id
        SQL
      end
    end
  end
end
