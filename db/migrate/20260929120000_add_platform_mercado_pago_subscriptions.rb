class AddPlatformMercadoPagoSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_mercado_pago_accounts do |t|
      t.string :singleton_key, null: false, default: "primary"
      t.text :access_token_ciphertext
      t.text :refresh_token_ciphertext
      t.string :mercado_pago_user_id
      t.string :mercado_pago_email
      t.boolean :live_mode
      t.datetime :expires_at
      t.datetime :connected_at
      t.datetime :disconnected_at
      t.integer :monthly_amount_cents, null: false, default: 2_500_000
      t.timestamps
    end
    add_index :platform_mercado_pago_accounts, :singleton_key, unique: true

    add_column :subscriptions, :provider, :string, null: false, default: "manual"
    add_column :subscriptions, :provider_subscription_id, :string
    add_column :subscriptions, :provider_status, :string
    add_index :subscriptions, :provider_subscription_id, unique: true
  end
end
