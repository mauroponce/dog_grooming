require "rails_helper"

RSpec.describe AppointmentPayment, type: :model do
  around do |example|
    original_environment = ENV["MERCADO_PAGO_ENV"]
    example.run
  ensure
    ENV["MERCADO_PAGO_ENV"] = original_environment
  end

  it "uses the sandbox checkout URL in Mercado Pago test mode" do
    ENV["MERCADO_PAGO_ENV"] = "test"
    payment = described_class.new(init_point: "https://www.mercadopago.com/checkout", sandbox_init_point: "https://sandbox.mercadopago.com/checkout")

    expect(payment.checkout_url).to eq("https://sandbox.mercadopago.com/checkout")
  end

  it "never redirects production checkout to a sandbox URL" do
    ENV["MERCADO_PAGO_ENV"] = "production"
    payment = described_class.new(init_point: nil, sandbox_init_point: "https://sandbox.mercadopago.com/checkout")

    expect { payment.checkout_url }.to raise_error(ArgumentError, /checkout productivo/)
  end
end
