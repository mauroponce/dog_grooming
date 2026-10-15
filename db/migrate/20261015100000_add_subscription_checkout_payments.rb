class AddSubscriptionCheckoutPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_mercado_pago_connections do |t|
      t.string :singleton_key, null: false
      t.text :access_token_ciphertext
      t.text :refresh_token_ciphertext
      t.string :mercado_pago_user_id
      t.string :mercado_pago_email
      t.string :mercado_pago_nickname
      t.datetime :expires_at
      t.datetime :connected_at
      t.datetime :disconnected_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :billing_mercado_pago_connections, :singleton_key, unique: true
    add_index :billing_mercado_pago_connections, :mercado_pago_user_id

    create_table :subscription_checkout_payments do |t|
      t.references :business, null: false, foreign_key: true
      t.references :subscription_invoice, null: false, foreign_key: true
      t.string :provider, null: false, default: "mercado_pago"
      t.string :status, null: false, default: "pending"
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "ARS"
      t.string :external_reference, null: false
      t.string :preference_id
      t.text :init_point
      t.text :sandbox_init_point
      t.string :provider_payment_id
      t.datetime :expires_at
      t.datetime :paid_at
      t.datetime :failed_at
      t.jsonb :raw_payload, null: false, default: {}
      t.timestamps
    end
    add_index :subscription_checkout_payments, :external_reference, unique: true
    add_index :subscription_checkout_payments, :provider_payment_id, unique: true
    add_index :subscription_checkout_payments, [ :subscription_invoice_id, :status ]

    reversible do |dir|
      dir.up do
        execute "UPDATE subscriptions SET amount_cents = 3000000 WHERE status IN ('trialing', 'payment_due', 'overdue', 'restricted', 'suspended')"
        execute "UPDATE subscription_invoices SET amount_cents = 3000000 WHERE status IN ('open', 'rejected', 'overdue')"
      end
    end
  end
end
