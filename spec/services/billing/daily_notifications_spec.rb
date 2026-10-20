require "rails_helper"

RSpec.describe Billing::DailyNotifications do
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    example.run
  ensure
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it "enqueues an ordinary reminder once at the daily notification run" do
    travel_to Time.zone.local(2026, 10, 19, 8, 30) do
      business = create_business
      business.update!(trial_ends_at: Time.current)
      Billing::DailyProcessor.call

      2.times { described_class.call }

      invoice = business.subscription.reload.current_invoice
      reminder = invoice.billing_reminders.find_by!(reminder_type: "due_today", channel: "email")
      expect(reminder).to have_attributes(status: "pending", event_on: Time.zone.today, sent_at: nil)
      expect(invoice.billing_reminders.where(reminder_type: "due_today").count).to eq(1)
      expect(enqueued_reminder_jobs_for(reminder).size).to eq(1)
    end
  end

  it "enqueues the final warning on the effective last grace day" do
    business = create_business
    due_on = 3.days.ago.to_date
    invoice = create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: Time.zone.today)

    described_class.call

    reminder = invoice.billing_reminders.find_by!(reminder_type: "overdue_3_days")
    expect(reminder.event_on).to eq(Time.zone.today)
    expect(enqueued_reminder_jobs_for(reminder).size).to eq(1)
  end

  it "moves the final warning to a manually extended grace date" do
    business = create_business
    due_on = 3.days.ago.to_date
    extended_grace_end = 5.days.from_now.to_date
    invoice = create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: extended_grace_end)

    described_class.call
    expect(invoice.billing_reminders.where(reminder_type: "overdue_3_days")).to be_empty

    described_class.new(today: extended_grace_end).call

    expect(invoice.billing_reminders.find_by!(reminder_type: "overdue_3_days").event_on).to eq(extended_grace_end)
  end

  it "enqueues the suspension notice only after lifecycle processing suspended the account" do
    business = create_business
    due_on = 4.days.ago.to_date
    invoice = create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: due_on + 3.days)
    Billing::DailyProcessor.call

    2.times { described_class.call }

    reminder = invoice.billing_reminders.find_by!(reminder_type: "suspended_notice")
    expect(reminder.event_on).to eq(due_on + 4.days)
    expect(invoice.billing_reminders.where(reminder_type: "suspended_notice").count).to eq(1)
    expect(enqueued_reminder_jobs_for(reminder).size).to eq(1)
  end

  it "sends the internal daily summary only once per recipient and Argentine date" do
    recipient = User.create!(
      email_address: "billing-summary-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :super_admin
    )

    expect {
      2.times { described_class.call }
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
        email_address: "daily-notifications-owner-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :admin
      )
      Business.create!(
        owner: owner,
        name: "Centro Daily Notifications",
        slug: "centro-daily-notifications-#{SecureRandom.hex(4)}",
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
        reference_code: "HT-NOTIFICATIONS-#{SecureRandom.hex(4).upcase}",
        status: status
      )
    end

    def enqueued_reminder_jobs_for(reminder)
      enqueued_jobs.select do |job|
        job.fetch(:job) == Billing::SendReminderJob && job.fetch(:args) == [ reminder.id ]
      end
    end
end
