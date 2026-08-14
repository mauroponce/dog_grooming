class RemoveMercadoPagoAndGoogleOauth < ActiveRecord::Migration[8.1]
  def change
    remove_index :appointments, :mercado_pago_payment_id, if_exists: true
    remove_index :appointments, :mercado_pago_preference_id, if_exists: true
    remove_column :appointments, :mercado_pago_init_point, :text, if_exists: true
    remove_column :appointments, :mercado_pago_payment_id, :string, if_exists: true
    remove_column :appointments, :mercado_pago_preference_id, :string, if_exists: true

    remove_column :businesses, :mercado_pago_access_token_ciphertext, :text, if_exists: true
    remove_column :businesses, :mercado_pago_connected_at, :datetime, if_exists: true
    remove_column :businesses, :mercado_pago_public_key, :string, if_exists: true
    remove_column :businesses, :mercado_pago_refresh_token_ciphertext, :text, if_exists: true
    remove_column :businesses, :mercado_pago_user_id, :string, if_exists: true

    remove_index :client_memberships, :mp_preapproval_id, if_exists: true
    remove_column :client_memberships, :mercado_pago_init_point, :text, if_exists: true
    remove_column :client_memberships, :mp_preapproval_id, :string, if_exists: true

    remove_index :subscriptions, :mercado_pago_preapproval_id, if_exists: true
    remove_column :subscriptions, :mercado_pago_init_point, :text, if_exists: true
    remove_column :subscriptions, :mercado_pago_preapproval_id, :string, if_exists: true
    remove_column :subscriptions, :mercado_pago_sandbox_init_point, :text, if_exists: true

    remove_index :users, :google_uid, if_exists: true
    remove_column :users, :google_connected_at, :datetime, if_exists: true
    remove_column :users, :google_uid, :string, if_exists: true
  end
end
