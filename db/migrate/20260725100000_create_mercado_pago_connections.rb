class CreateMercadoPagoConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :mercado_pago_connections do |t|
      t.references :business, null: false, foreign_key: true, index: { unique: true }
      t.string :mercado_pago_user_id
      t.string :public_key
      t.text :access_token_ciphertext
      t.text :refresh_token_ciphertext
      t.datetime :expires_at
      t.datetime :connected_at
      t.datetime :disconnected_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :mercado_pago_connections, :mercado_pago_user_id
  end
end
