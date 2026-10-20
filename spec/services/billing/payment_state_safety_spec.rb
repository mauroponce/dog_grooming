require "rails_helper"

RSpec.describe "Billing payment state safety" do
  it "does not reject an invoice that was already paid" do
    business = create_business
    invoice = create_invoice(business, status: "paid")
    reviewer = create_user(:super_admin)

    expect do
      Billing::RejectPayment.call(invoice: invoice, reviewer: reviewer, reason: "No coincide")
    end.to raise_error(ArgumentError, "La factura ya no está pendiente de revisión.")

    expect(invoice.reload).to be_paid
    expect(business.subscription.reload.status).not_to eq("payment_due")
  end

  it "does not attach a proof to a paid invoice" do
    business = create_business
    invoice = create_invoice(business, status: "paid")

    expect do
      Billing::UploadPaymentProof.call(invoice: invoice, file: image_upload, uploaded_by: business.owner)
    end.to raise_error(ArgumentError, "La factura ya no admite comprobantes.")

    expect(invoice.subscription_payment_proofs).to be_empty
  end

  it "reuses the current invoice while holding the business creation boundary" do
    business = create_business
    business.update!(trial_ends_at: Time.current)

    first = Billing::EnsureCurrentInvoice.call(business: business, force: true)
    second = Billing::EnsureCurrentInvoice.call(business: business.reload, force: true)

    expect(second).to eq(first)
    expect(business.subscription.subscription_invoices.count).to eq(1)
  end

  private

    def create_user(role)
      User.create!(
        email_address: "billing-safety-#{role}-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: role
      )
    end

    def create_business
      Business.create!(
        owner: create_user(:admin),
        name: "Patitas Billing Safety",
        slug: "patitas-billing-safety-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-1234",
        onboarding_completed_at: Time.current
      )
    end

    def create_invoice(business, status:)
      due_on = Time.zone.today
      business.subscription.subscription_invoices.create!(
        business: business,
        period_start: due_on,
        period_end: due_on.advance(months: 1),
        billing_period_months: 1,
        amount_cents: business.monthly_amount_cents,
        due_on: due_on,
        reference_code: "HT-SAFETY-#{SecureRandom.hex(4).upcase}",
        status: status,
        paid_at: (Time.current if status == "paid")
      )
    end

    def image_upload
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/service-gallery.png").to_s,
        "image/png"
      )
    end
end
