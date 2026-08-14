class CreatePaymentAccounts < ActiveRecord::Migration[8.0]
  class MigrationBusiness < ActiveRecord::Base
    self.table_name = "businesses"
  end

  class MigrationPaymentAccount < ActiveRecord::Base
    self.table_name = "payment_accounts"
  end

  def up
    create_table :payment_accounts do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.text :details, null: false
      t.boolean :primary_account, null: false, default: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :payment_accounts,
      :business_id,
      unique: true,
      where: "primary_account = TRUE",
      name: "idx_payment_accounts_one_primary_per_business"

    add_reference :services, :payment_account, foreign_key: { on_delete: :nullify }

    backfill_payment_accounts!
  end

  def down
    remove_reference :services, :payment_account, foreign_key: true
    drop_table :payment_accounts
  end

  private
    def backfill_payment_accounts!
      say_with_time "Backfilling payment accounts from legacy deposit preferences" do
        MigrationBusiness.reset_column_information
        MigrationPaymentAccount.reset_column_information

        MigrationBusiness.find_each do |business|
          details = legacy_payment_details_for(business.preferences.to_h)
          next if details.blank?

          MigrationPaymentAccount.create!(
            business_id: business.id,
            name: "Cuenta principal",
            details: details,
            primary_account: true,
            active: true,
            created_at: Time.current,
            updated_at: Time.current
          )
        end
      end
    end

    def legacy_payment_details_for(preferences)
      lines = []
      lines << "Alias: #{preferences.fetch("deposit_alias", "").to_s.strip}" if preferences.fetch("deposit_alias", "").to_s.strip.present?
      lines << "CBU/CVU: #{preferences.fetch("deposit_account", "").to_s.strip}" if preferences.fetch("deposit_account", "").to_s.strip.present?
      lines << "Titular: #{preferences.fetch("deposit_holder", "").to_s.strip}" if preferences.fetch("deposit_holder", "").to_s.strip.present?
      lines << "CUIT/CUIL: #{preferences.fetch("deposit_tax_id", "").to_s.strip}" if preferences.fetch("deposit_tax_id", "").to_s.strip.present?
      lines << "Link de pago: #{preferences.fetch("deposit_payment_link", "").to_s.strip}" if preferences.fetch("deposit_payment_link", "").to_s.strip.present?

      instructions = preferences.fetch("deposit_instructions", "").to_s.strip
      lines << "" << instructions if instructions.present?
      lines.join("\n").presence
    end
end
