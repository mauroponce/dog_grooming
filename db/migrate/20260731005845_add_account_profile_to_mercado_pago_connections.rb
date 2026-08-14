class AddAccountProfileToMercadoPagoConnections < ActiveRecord::Migration[8.0]
  def change
    add_column :mercado_pago_connections, :mercado_pago_email, :string
    add_column :mercado_pago_connections, :mercado_pago_nickname, :string

    add_index :mercado_pago_connections, :mercado_pago_email
  end
end
