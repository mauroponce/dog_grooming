require "rails_helper"

RSpec.describe Public::BusinessLandingPresenter do
  it "describes Mercado Pago instead of the retired manual proof flow" do
    owner = User.create!(email_address: "landing-deposit-#{SecureRandom.hex(4)}@example.com", role: :admin)
    business = Business.create!(
      owner: owner,
      name: "Patitas Landing",
      slug: "patitas-landing-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current,
      preferences: { "deposits_enabled" => true }
    )
    service = business.services.create!(
      name: "Baño",
      category: "Baño",
      duration_minutes: 45,
      price_cents: 20_000_00,
      deposit_required: true,
      deposit_amount_cents: 5_000_00
    )

    deposit_answer = described_class.new(business: business, service: service)
      .faq_items(for_service: service)
      .find { |item| item.fetch(:question) == "¿Tengo que pagar seña?" }
      .fetch(:answer)

    expect(deposit_answer).to include("Mercado Pago")
    expect(deposit_answer).not_to include("comprobante")
  end
end
