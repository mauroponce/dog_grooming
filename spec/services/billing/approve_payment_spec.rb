require "rails_helper"

RSpec.describe Billing::ApprovePayment do
  it "activa 30 días desde la aprobación luego de una cuenta suspendida" do
    business = create_business
    invoice = create_invoice(business, due_on: 4.days.ago)
    business.subscription.update!(status: "suspended", paid_until: 2.days.ago)

    described_class.call(invoice: invoice, reviewer: create_super_admin)

    expect(invoice.reload).to be_paid
    expect(business.subscription.reload).to have_attributes(
      status: "active",
      paid_until: Time.zone.today + 30.days,
      next_due_on: Time.zone.today + 30.days
    )
  end

  it "conserva los días ya pagos en una renovación anticipada" do
    business = create_business
    invoice = create_invoice(business, due_on: 20.days.from_now)
    business.subscription.update!(status: "active", paid_until: 20.days.from_now.to_date)

    described_class.call(invoice: invoice, reviewer: create_super_admin)

    expect(business.subscription.reload.paid_until).to eq(50.days.from_now.to_date)
  end

  private

  def create_business
    owner = User.create!(email_address: "owner-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    Business.create!(owner: owner, name: "Patitas", slug: "patitas-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 4444 4444", onboarding_completed_at: Time.current)
  end

  def create_super_admin
    User.create!(email_address: "super-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :super_admin)
  end

  def create_invoice(business, due_on:)
    business.subscription.subscription_invoices.create!(business: business, period_start: due_on.to_date, period_end: due_on.to_date + 30.days, billing_period_months: 1, amount_cents: business.monthly_amount_cents, due_on: due_on.to_date, reference_code: "PAY-#{SecureRandom.hex(5)}", status: "open")
  end
end
