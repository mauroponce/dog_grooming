require "rails_helper"

RSpec.describe MercadoPago::Client do
  it "bounds network calls and exposes transport failures as integration errors" do
    expect(Net::HTTP).to receive(:start).with(
      "api.mercadopago.com",
      443,
      use_ssl: true,
      open_timeout: 5,
      read_timeout: 10
    ).and_raise(Net::OpenTimeout)

    expect do
      described_class.new(access_token: "test-token").fetch_payment!("payment-1")
    end.to raise_error(described_class::Error, /No pudimos comunicarnos con Mercado Pago/)
  end
end
