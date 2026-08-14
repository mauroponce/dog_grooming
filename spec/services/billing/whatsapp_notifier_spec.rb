require "rails_helper"

RSpec.describe Billing::WhatsAppNotifier do
  around do |example|
    previous_provider = ENV["WHATSAPP_PROVIDER"]
    ENV["WHATSAPP_PROVIDER"] = "evolution"
    example.run
  ensure
    ENV["WHATSAPP_PROVIDER"] = previous_provider
  end

  it "does not send the trial-ended payment instructions to WhatsApp" do
    business = create_business
    business.update!(
      trial_ends_at: Time.current,
      whatsapp_notifications_enabled: true,
      whatsapp_notifications_phone: "+54 9 11 5555-1234",
      whatsapp_opted_in_at: Time.current,
      whatsapp_opted_out_at: nil
    )
    BillingTransferAccount.create!(
      transfer_alias: "dog.grooming",
      cbu: "0000003100012345678901",
      account_holder: "Dog Grooming SRL"
    )
    invoice = create_invoice(business)
    client = instance_double(
      WhatsApp::EvolutionClient,
      configured?: true,
      send_text: { success: true, status: 201, body: {} }
    )

    result = described_class.call(invoice: invoice, reminder_type: "due_today", client: client)

    expect(result.status).to eq(:skipped)
    expect(client).not_to have_received(:send_text)
  end

  it "does not contact a business without WhatsApp notification consent" do
    business = create_business
    invoice = create_invoice(business)
    client = instance_spy(WhatsApp::EvolutionClient, configured?: true)

    result = described_class.call(invoice: invoice, reminder_type: "due_today", client: client)

    expect(result.status).to eq(:skipped)
    expect(client).not_to have_received(:send_text)
  end

  private
    def create_business
      owner = User.create!(
        email_address: "billing-owner-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :admin
      )
      Business.create!(
        owner: owner,
        name: "Centro Cobros",
        slug: "centro-cobros-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-1234",
        onboarding_completed_at: Time.current
      )
    end

    def create_invoice(business)
      due_on = Time.zone.today
      business.subscription.subscription_invoices.create!(
        business: business,
        period_start: due_on,
        period_end: due_on.advance(months: 1),
        billing_period_months: 1,
        amount_cents: business.monthly_amount_cents,
        due_on: due_on,
        reference_code: "HT-WA-#{SecureRandom.hex(4).upcase}",
        status: "open"
      )
    end
end
