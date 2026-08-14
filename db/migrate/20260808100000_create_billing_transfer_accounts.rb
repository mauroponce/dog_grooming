class CreateBillingTransferAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_transfer_accounts do |t|
      t.string :singleton_key, null: false, default: "primary"
      t.string :transfer_alias
      t.string :cbu
      t.string :account_holder
      t.string :tax_id
      t.timestamps
    end

    add_index :billing_transfer_accounts, :singleton_key, unique: true
  end
end
