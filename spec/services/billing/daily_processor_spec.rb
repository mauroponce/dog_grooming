require "rails_helper"

RSpec.describe Billing::DailyProcessor do
  include ActiveSupport::Testing::TimeHelpers

  it "recovers stale notifications on every processing run" do
    scheduler = instance_double(Billing::ReminderScheduler, recover_stale!: true)
    allow(Billing::ReminderScheduler).to receive(:new).and_return(scheduler)

    described_class.call

    expect(scheduler).to have_received(:recover_stale!).once
  end

  it "does not create ordinary reminders during an overnight processing run" do
    travel_to Time.zone.local(2026, 10, 19, 2, 15) do
      business = create_business
      business.update!(trial_ends_at: Time.current)

      described_class.call

      expect(business.subscription.reload.current_invoice).to be_present
      expect(BillingReminder.where(business: business)).to be_empty
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  it "keeps access throughout all three grace days and suspends at the next Argentine midnight" do
    business = create_business
    due_on = Date.new(2026, 10, 15)
    invoice = create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: due_on + 3.days)

    travel_to Time.utc(2026, 10, 19, 2, 59, 59) do
      described_class.call
      expect(business.subscription.reload).not_to be_suspended
      expect(business).to be_access_active
    end

    travel_to Time.utc(2026, 10, 19, 3, 0, 0) do
      described_class.call
      expect(business.subscription.reload).to be_suspended
      expect(invoice.reload.suspended_at).to eq(Time.current)
      expect(business).not_to be_access_active
    end
  end

  it "respects a manually extended grace date" do
    business = create_business
    due_on = 4.days.ago.to_date
    create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: 6.days.from_now.to_date)

    described_class.call

    expect(business.subscription.reload).to be_overdue
    expect(business).to be_access_active
  end

  it "does not suspend a payment pending review after grace expires" do
    business = create_business
    due_on = 5.days.ago.to_date
    invoice = create_invoice(business, due_on: due_on, status: "pending_review")
    business.subscription.update!(status: "pending_review", next_due_on: due_on, grace_ends_on: due_on + 3.days)

    described_class.call

    expect(invoice.reload).to be_pending_review
    expect(business.subscription.reload).to be_pending_review
    expect(business).to be_access_active
  end

  it "is idempotent when two processing executions cover the same suspension" do
    business = create_business
    due_on = 4.days.ago.to_date
    invoice = create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: due_on + 3.days)

    first_processor = described_class.new
    second_processor = described_class.new
    first_processor.call
    suspended_at = business.subscription.reload.suspended_at
    invoice_suspended_at = invoice.reload.suspended_at
    second_processor.call

    expect(business.subscription.reload).to have_attributes(status: "suspended", suspended_at: suspended_at)
    expect(invoice.reload.suspended_at).to eq(invoice_suspended_at)
    expect(invoice.billing_reminders).to be_empty
  end

  private
    def create_business
      owner = User.create!(
        email_address: "daily-billing-owner-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :admin
      )
      Business.create!(
        owner: owner,
        name: "Centro Daily Billing",
        slug: "centro-daily-billing-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-1234",
        onboarding_completed_at: Time.current
      )
    end

    def create_invoice(business, due_on:, status: "open")
      business.subscription.subscription_invoices.create!(
        business: business,
        period_start: due_on,
        period_end: due_on.advance(months: 1),
        billing_period_months: 1,
        amount_cents: business.monthly_amount_cents,
        due_on: due_on,
        reference_code: "HT-DAILY-#{SecureRandom.hex(4).upcase}",
        status: status
      )
    end
end
