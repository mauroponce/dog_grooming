class AddCustomDomainToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :custom_domain, :string
    add_column :businesses, :custom_domain_enabled, :boolean, default: false, null: false
    add_index :businesses, :custom_domain, unique: true, where: "custom_domain IS NOT NULL"
    add_index :businesses, [ :custom_domain, :custom_domain_enabled ], name: "index_businesses_on_custom_domain_and_enabled"
  end
end
