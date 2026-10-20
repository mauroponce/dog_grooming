require "rails_helper"

RSpec.describe Billing::SendReminderJob, type: :job do
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

  it "marks the reminder sent only after the mailer processes it" do
    reminder = create_reminder
    delivery = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    allow(BillingMailer).to receive(:reminder).and_return(delivery)

    described_class.perform_now(reminder.id)

    expect(delivery).to have_received(:deliver_now).once
    expect(reminder.reload).to be_sent
    expect(reminder.sent_at).to be_present
  end

  it "keeps the reminder failed and schedules a retry when delivery raises" do
    reminder = create_reminder(reminder_type: "suspended_notice")
    delivery = instance_double(ActionMailer::MessageDelivery)
    allow(delivery).to receive(:deliver_now).and_raise(Net::OpenTimeout, "provider unavailable")
    allow(BillingMailer).to receive(:account_suspended).and_return(delivery)

    described_class.perform_now(reminder.id)

    expect(reminder.reload).to have_attributes(status: "failed", sent_at: nil)
    expect(enqueued_jobs.count { |job| job.fetch(:job) == described_class }).to eq(1)
  end

  it "does not deliver an already sent reminder again" do
    reminder = create_reminder(status: "sent", sent_at: Time.current)
    expect(BillingMailer).not_to receive(:reminder)

    described_class.perform_now(reminder.id)
  end

  it "skips an enqueued reminder after the invoice due date changes" do
    reminder = create_reminder
    reminder.subscription_invoice.update!(due_on: reminder.event_on + 7.days)
    expect(BillingMailer).not_to receive(:reminder)

    described_class.perform_now(reminder.id)

    expect(reminder.reload).to have_attributes(status: "skipped", sent_at: nil)
  end

  it "skips an enqueued overdue reminder after a proof enters review" do
    reminder = create_reminder(reminder_type: "overdue_2_days", event_on: 2.days.ago.to_date)
    reminder.subscription_invoice.update!(status: "pending_review")
    reminder.subscription_invoice.subscription.update!(status: "pending_review")
    expect(BillingMailer).not_to receive(:reminder)

    described_class.perform_now(reminder.id)

    expect(reminder.reload).to have_attributes(status: "skipped", sent_at: nil)
  end

  private
    def create_reminder(reminder_type: "due_today", status: "pending", sent_at: nil, event_on: Time.zone.today)
      owner = User.create!(email_address: "billing-job-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
      business = Business.create!(owner: owner, name: "Billing Job", slug: "billing-job-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-1234", onboarding_completed_at: Time.current)
      invoice = business.subscription.subscription_invoices.create!(
        business: business,
        period_start: event_on,
        period_end: 1.month.from_now.to_date,
        billing_period_months: 1,
        amount_cents: business.monthly_amount_cents,
        due_on: event_on,
        reference_code: "HT-JOB-#{SecureRandom.hex(4).upcase}",
        status: "open"
      )
      if reminder_type == "suspended_notice"
        business.subscription.update!(status: "suspended", grace_ends_on: event_on - 1.day, suspended_at: Time.current)
        invoice.update!(status: "overdue", suspended_at: Time.current)
      end
      invoice.billing_reminders.create!(
        business: business,
        reminder_type: reminder_type,
        channel: "email",
        recipient: owner.email_address,
        event_on: event_on,
        status: status,
        sent_at: sent_at
      )
    end
end
