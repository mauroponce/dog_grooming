class CreateAppointmentPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :appointment_payments do |t|
      t.references :business, null: false, foreign_key: true
      t.references :appointment, null: false, foreign_key: true
      t.string :provider, null: false, default: "mercado_pago"
      t.string :status, null: false, default: "pending"
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: "ARS"
      t.string :external_reference, null: false
      t.string :preference_id
      t.text :init_point
      t.text :sandbox_init_point
      t.string :provider_payment_id
      t.string :provider_merchant_order_id
      t.datetime :paid_at
      t.datetime :failed_at
      t.jsonb :raw_payload, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :appointment_payments, [ :business_id, :status ]
    add_index :appointment_payments, :external_reference, unique: true
    add_index :appointment_payments, :preference_id
    add_index :appointment_payments, :provider_payment_id
  end
end
