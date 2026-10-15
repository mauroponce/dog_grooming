require "rails_helper"

RSpec.describe Billing::CreateMercadoPagoCheckout do
  it "creates and reuses a checkout de plataforma para la factura" do
    business = create_business
    invoice = create_invoice(business)
    connection = BillingMercadoPagoConnection.current
    connection.update!(access_token: "APP_USR-platform", connected_at: Time.current)
    client = instance_double(MercadoPago::Client, create_preference!: { "id" => "pref-1", "sandbox_init_point" => "https://sandbox.mercadopago.com/checkout" })
    allow(MercadoPago::Client).to receive(:for_connection).with(connection).and_return(client)

    payment = described_class.call(invoice: invoice, host: "localhost", protocol: "http")

    expect(payment.business).to eq(business)
    expect(payment.amount_cents).to eq(3_000_000)
    expect(payment.external_reference).to start_with("cita-pet-invoice-")
    expect(described_class.call(invoice: invoice, host: "localhost", protocol: "http")).to eq(payment)
  end

  def create_business
    owner = User.create!(email_address: "billing-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    Business.create!(owner: owner, name: "Patitas", slug: "patitas-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555 5555", onboarding_completed_at: Time.current)
  end

  def create_invoice(business)
    business.subscription.subscription_invoices.create!(business: business, period_start: Date.current, period_end: 1.month.from_now.to_date, billing_period_months: 1, amount_cents: 3_000_000, due_on: Date.current, reference_code: "CT-#{SecureRandom.hex(5)}")
  end
end
