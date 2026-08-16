require "rails_helper"

RSpec.describe BillingMailer, type: :mailer do
  it "renders configured transfer details and the billing page link in a payment reminder" do
    business = create_business
    invoice = create_invoice(business)
    BillingTransferAccount.create!(
      transfer_alias: "dog.grooming",
      cbu: "0000003100012345678901",
      account_holder: "Cita.pet SRL"
    )

    mail = described_class.reminder(invoice, "due_today")

    expect(mail.to).to eq([ business.owner.email_address ])
    expect(mail.html_part.body.encoded).to include("dog.grooming", "0000003100012345678901", "/admin/suscripcion")
    expect(mail.text_part.body.encoded).to include("Alias: dog.grooming", "CBU/CVU: 0000003100012345678901", "/admin/suscripcion")
  end

  private
    def create_business
      owner = User.create!(
        email_address: "mailer-owner-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :admin
      )
      Business.create!(
        owner: owner,
        name: "Centro Mailer",
        slug: "centro-mailer-#{SecureRandom.hex(4)}",
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
        reference_code: "HT-MAIL-#{SecureRandom.hex(4).upcase}",
        status: "open"
      )
    end
end
