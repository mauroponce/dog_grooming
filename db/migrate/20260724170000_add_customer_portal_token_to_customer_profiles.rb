class AddCustomerPortalTokenToCustomerProfiles < ActiveRecord::Migration[8.0]
  class MigrationCustomerProfile < ApplicationRecord
    self.table_name = "customer_profiles"
  end

  def up
    add_column :customer_profiles, :customer_portal_token, :string

    MigrationCustomerProfile.reset_column_information
    MigrationCustomerProfile.where(customer_portal_token: [ nil, "" ]).find_each do |profile|
      profile.update_columns(customer_portal_token: unique_customer_portal_token)
    end

    change_column_null :customer_profiles, :customer_portal_token, false
    add_index :customer_profiles, :customer_portal_token, unique: true
  end

  def down
    remove_index :customer_profiles, :customer_portal_token
    remove_column :customer_profiles, :customer_portal_token
  end

  private
    def unique_customer_portal_token
      loop do
        token = SecureRandom.urlsafe_base64(24)
        break token unless MigrationCustomerProfile.exists?(customer_portal_token: token)
      end
    end
end
