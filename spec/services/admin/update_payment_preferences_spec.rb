require "rails_helper"

RSpec.describe Admin::UpdatePaymentPreferences do
  it "persists Mercado Pago as the only enabled payment method" do
    business = create_business

    described_class.call(business, {
      "enabled_payment_methods" => [ "", "mercado_pago" ]
    })

    expect(business.reload.enabled_payment_methods).to eq([ "mercado_pago" ])
    expect(business.preferences.fetch("enabled_payment_methods")).to eq([ "mercado_pago" ])
  end

  it "falls back to Mercado Pago when unsupported methods are submitted" do
    business = create_business

    described_class.call(business, {
      "enabled_payment_methods" => [ "manual_transfer", "cash" ]
    })

    expect(business.reload.enabled_payment_methods).to eq([ "mercado_pago" ])
  end

  it "keeps Mercado Pago enabled when an empty selection is submitted" do
    business = create_business

    described_class.call(business, { "enabled_payment_methods" => [ "" ] })

    expect(business.reload.enabled_payment_methods).to eq([ "mercado_pago" ])
  end

  def create_business
    owner = User.create!(
      email_address: "payment-preferences-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )

    owner.create_business!(
      name: "Payment Preferences Center",
      slug: "payment-preferences-center-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )
  end
end
