require "rails_helper"

RSpec.describe Admin::UpdatePaymentPreferences do
  it "persists only one enabled payment method" do
    business = create_business

    described_class.call(business, {
      "enabled_payment_methods" => [ "", "manual_transfer", "mercado_pago" ]
    })

    expect(business.reload.enabled_payment_methods).to eq([ "mercado_pago" ])
    expect(business.preferences.fetch("enabled_payment_methods")).to eq([ "mercado_pago" ])
  end

  it "ignores unknown payment methods" do
    business = create_business

    described_class.call(business, {
      "enabled_payment_methods" => [ "manual_transfer", "cash" ]
    })

    expect(business.reload.enabled_payment_methods).to eq([ "manual_transfer" ])
  end

  it "requires at least one enabled payment method" do
    business = create_business

    expect {
      described_class.call(business, { "enabled_payment_methods" => [ "" ] })
    }.to raise_error(ArgumentError, "Elegí al menos un método de pago habilitado.")
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
