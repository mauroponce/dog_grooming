require "rails_helper"

RSpec.describe Billing::DailyProcessor do
  include ActiveSupport::Testing::TimeHelpers

  it "notifies by email when a trial reaches its payment date" do
    business = create_business
    business.update!(trial_ends_at: Time.current)
    mail_delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
    allow(BillingMailer).to receive(:reminder).and_return(mail_delivery)

    2.times { described_class.new(today: Time.zone.today).call }

    invoice = business.subscription.reload.current_invoice
    expect(invoice).to be_present
    expect(invoice.due_on).to eq(Time.zone.today)
    expect(BillingMailer).to have_received(:reminder).with(invoice, "due_today").once
    expect(mail_delivery).to have_received(:deliver_later).once
    expect(invoice.billing_reminders.find_by!(reminder_type: "due_today", channel: "email")).to be_sent
  end

  it "does not suspend on any grace day and suspends on the following day" do
    business = create_business
    due_on = Time.zone.today
    invoice = create_invoice(business, due_on: due_on)
    business.update!(trial_ends_at: Time.current)
    business.subscription.update!(status: "payment_due", next_due_on: due_on, grace_ends_on: due_on + 3.days)

    (1..3).each do |days_overdue|
      travel_to((due_on + days_overdue.days).in_time_zone.noon) do
        described_class.new(today: Time.zone.today).call
        expect(business.subscription.reload).not_to be_suspended
        expect(business).to be_access_active
      end
    end

    travel_to((due_on + 4.days).in_time_zone.beginning_of_day) do
      described_class.new(today: Time.zone.today).call
      expect(business.subscription.reload).to be_suspended
      expect(invoice.reload.suspended_at).to be_present
      expect(business).not_to be_access_active
    end
  end

  it "respects a manually extended grace date" do
    business = create_business
    due_on = 4.days.ago.to_date
    create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: 6.days.from_now.to_date)

    described_class.new(today: Time.zone.today).call

    expect(business.subscription.reload).to be_overdue
    expect(business).to be_access_active
  end

  it "does not suspend a payment pending review after grace expires" do
    business = create_business
    due_on = 5.days.ago.to_date
    invoice = create_invoice(business, due_on: due_on, status: "pending_review")
    business.subscription.update!(status: "pending_review", next_due_on: due_on, grace_ends_on: due_on + 3.days)

    described_class.new(today: Time.zone.today).call

    expect(invoice.reload).to be_pending_review
    expect(business.subscription.reload).to be_pending_review
    expect(business).to be_access_active
  end

  it "is idempotent when run repeatedly for reminders and suspension" do
    business = create_business
    due_on = 4.days.ago.to_date
    invoice = create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: due_on + 3.days)
    suspension_delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
    allow(BillingMailer).to receive(:account_suspended).and_return(suspension_delivery)

    2.times { described_class.new(today: Time.zone.today).call }

    expect(BillingMailer).to have_received(:account_suspended).once
    expect(suspension_delivery).to have_received(:deliver_later).once
    expect(invoice.billing_reminders.where(reminder_type: "suspended_notice", channel: "email").count).to eq(1)
  end

  it "sends the internal daily summary only once per recipient and date" do
    recipient = User.create!(email_address: "billing-summary-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :super_admin)

    expect {
      2.times { described_class.new(today: Time.zone.today).call }
    }.to change { ActionMailer::Base.deliveries.count }.by(1)

    expect(
      EmailDeliveryLog.where(
        mailer: "BillingMailer",
        action: "daily_summary",
        recipient: recipient.email_address,
        status: "sent",
        created_at: Time.zone.today.all_day
      ).count
    ).to eq(1)
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
