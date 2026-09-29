require "rails_helper"

RSpec.describe PlatformMercadoPago::SyncSubscription do
  it "solo habilita acceso después de un cobro aprobado" do
    owner = User.create!(email_address: "mp-owner@example.com", password: "password123", role: :admin)
    business = Business.create!(owner: owner, name: "Perritos MP", slug: "perritos-mp",
      contact_phone: "+54 11 5555 5555", onboarding_completed_at: Time.current)
    business.update!(trial_ends_at: 1.minute.ago)
    subscription = business.subscription
    subscription.update!(provider: "mercado_pago", provider_subscription_id: "preapproval-123")

    client = instance_double(PlatformMercadoPago::Client)
    allow(PlatformMercadoPago::Client).to receive(:new).and_return(client)
    allow(client).to receive(:fetch_subscription!).with("preapproval-123").and_return(
      { "id" => "preapproval-123", "external_reference" => subscription.external_reference, "status" => "authorized" }
    )
    allow(client).to receive(:search_authorized_payments!).with("preapproval-123").and_return("results" => [])

    described_class.call(subscription)
    expect(business.reload.access_active?).to be(false)

    allow(client).to receive(:search_authorized_payments!).with("preapproval-123").and_return("results" => [
      { "preapproval_id" => "preapproval-123", "debit_date" => Time.current.iso8601,
        "payment" => { "status" => "approved" } }
    ])
    described_class.call(subscription.reload)
    expect(business.reload.access_active?).to be(true)

    allow(client).to receive(:fetch_subscription!).with("preapproval-123").and_return(
      { "id" => "preapproval-123", "external_reference" => subscription.external_reference, "status" => "paused" }
    )
    described_class.call(subscription.reload)
    expect(business.reload.access_active?).to be(false)
  end
end
