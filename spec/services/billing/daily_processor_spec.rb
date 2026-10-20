require "rails_helper"

RSpec.describe Billing::DailyProcessor do
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

  it "notifies by email when a trial reaches its payment date" do
    business = create_business
    business.update!(trial_ends_at: Time.current)

    2.times { described_class.new(today: Time.zone.today).call }

    invoice = business.subscription.reload.current_invoice
    reminder = invoice.billing_reminders.find_by!(reminder_type: "due_today", channel: "email")
    expect(invoice).to be_present
    expect(invoice.due_on).to eq(Time.zone.today)
    expect(reminder).to have_attributes(status: "pending", event_on: Time.zone.today, sent_at: nil)
    expect(enqueued_reminder_jobs_for(reminder).size).to eq(1)
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
    expect(invoice.billing_reminders).to be_empty
  end

  it "is idempotent when run repeatedly for reminders and suspension" do
    business = create_business
    due_on = 4.days.ago.to_date
    invoice = create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: due_on + 3.days)
    2.times { described_class.new(today: Time.zone.today).call }

    reminder = invoice.billing_reminders.find_by!(reminder_type: "suspended_notice", channel: "email")
    expect(reminder).to have_attributes(status: "pending", event_on: due_on + 4.days, sent_at: nil)
    expect(invoice.billing_reminders.where(reminder_type: "suspended_notice", channel: "email").count).to eq(1)
    expect(enqueued_reminder_jobs_for(reminder).size).to eq(1)
  end

  it "sends the final warning on the effective last grace day" do
    business = create_business
    due_on = 3.days.ago.to_date
    invoice = create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: Time.zone.today)

    described_class.new(today: Time.zone.today).call

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

    described_class.new(today: Time.zone.today).call
    expect(invoice.billing_reminders.where(reminder_type: "overdue_3_days")).to be_empty

    described_class.new(today: extended_grace_end).call

    reminder = invoice.billing_reminders.find_by!(reminder_type: "overdue_3_days")
    expect(reminder.event_on).to eq(extended_grace_end)
  end

  it "keeps a failed suspension notice retryable when enqueueing fails" do
    business = create_business
    due_on = 4.days.ago.to_date
    invoice = create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: due_on + 3.days)
    allow(Billing::SendReminderJob).to receive(:new).and_raise(ActiveJob::EnqueueError, "queue unavailable")

    described_class.new(today: Time.zone.today).call

    reminder = invoice.billing_reminders.find_by!(reminder_type: "suspended_notice")
    expect(business.subscription.reload).to be_suspended
    expect(invoice.reload.suspended_at).to be_present
    expect(reminder).to have_attributes(status: "failed", sent_at: nil, enqueued_at: nil)
  end

  it "retries a suspension notice after a prior enqueue failure" do
    business = create_business
    due_on = 4.days.ago.to_date
    invoice = create_invoice(business, due_on: due_on)
    business.subscription.update!(status: "overdue", next_due_on: due_on, grace_ends_on: due_on + 3.days)
    allow(Billing::SendReminderJob).to receive(:new).and_raise(ActiveJob::EnqueueError, "queue unavailable")
    described_class.new(today: Time.zone.today).call
    reminder = invoice.billing_reminders.find_by!(reminder_type: "suspended_notice")

    allow(Billing::SendReminderJob).to receive(:new).and_call_original
    described_class.new(today: Time.zone.today).call

    expect(reminder.reload).to have_attributes(status: "pending", sent_at: nil)
    expect(reminder.enqueued_at).to be_present
  end

  it "does not duplicate a recently enqueued job that has not run yet" do
    business = create_business
    invoice = create_invoice(business, due_on: Time.zone.today)
    active_job_id = SecureRandom.uuid
    reminder = create_reminder(invoice, enqueued_at: 5.minutes.ago, active_job_id: active_job_id)

    described_class.new(today: Time.zone.today).call

    expect(reminder.reload).to have_attributes(status: "pending", active_job_id: active_job_id)
    expect(enqueued_reminder_jobs_for(reminder)).to be_empty
  end

  it "leaves a stale reminder alone while its Solid Queue job is still active" do
    business = create_business
    invoice = create_invoice(business, due_on: Time.zone.today)
    active_job_id = SecureRandom.uuid
    reminder = create_reminder(invoice, enqueued_at: 2.hours.ago, active_job_id: active_job_id)
    processor = described_class.new(today: Time.zone.today)
    allow(processor).to receive(:active_job_present?).with(reminder.active_job_id).and_return(true)

    processor.call

    expect(reminder.reload.active_job_id).to eq(active_job_id)
    expect(enqueued_reminder_jobs_for(reminder)).to be_empty
  end

  it "recovers a stale pending reminder after its Solid Queue job disappears" do
    business = create_business
    invoice = create_invoice(business, due_on: Time.zone.today)
    missing_job_id = SecureRandom.uuid
    reminder = create_reminder(invoice, enqueued_at: 2.hours.ago, active_job_id: missing_job_id)
    processor = described_class.new(today: Time.zone.today)
    allow(processor).to receive(:active_job_present?).with(missing_job_id).and_return(false)

    processor.call

    expect(reminder.reload).to have_attributes(status: "pending")
    expect(reminder.active_job_id).to be_present
    expect(reminder.active_job_id).not_to eq(missing_job_id)
    expect(enqueued_reminder_jobs_for(reminder).size).to eq(1)
  end

  it "recovers a failed delivery after Active Job has no active retry" do
    business = create_business
    invoice = create_invoice(business, due_on: Time.zone.today)
    failed_job_id = SecureRandom.uuid
    reminder = create_reminder(
      invoice,
      status: "failed",
      enqueued_at: 2.hours.ago,
      active_job_id: failed_job_id,
      updated_at: 2.hours.ago
    )
    processor = described_class.new(today: Time.zone.today)
    allow(processor).to receive(:active_job_present?).with(failed_job_id).and_return(false)

    processor.call

    expect(reminder.reload).to have_attributes(status: "pending")
    expect(reminder.active_job_id).not_to eq(failed_job_id)
    expect(enqueued_reminder_jobs_for(reminder).size).to eq(1)
  end

  it "recovers a stale suspension notice without changing the suspension" do
    business = create_business
    due_on = 4.days.ago.to_date
    invoice = create_invoice(business, due_on: due_on, status: "overdue")
    business.subscription.update!(status: "suspended", grace_ends_on: due_on + 3.days, suspended_at: 2.hours.ago)
    invoice.update!(suspended_at: 2.hours.ago)
    reminder = create_reminder(
      invoice,
      reminder_type: "suspended_notice",
      event_on: due_on + 4.days,
      enqueued_at: 2.hours.ago,
      active_job_id: SecureRandom.uuid
    )
    processor = described_class.new(today: Time.zone.today)
    allow(processor).to receive(:active_job_present?).with(reminder.active_job_id).and_return(false)

    expect { processor.call }.not_to change { business.subscription.reload.suspended_at }

    expect(reminder.reload.status).to eq("pending")
    expect(enqueued_reminder_jobs_for(reminder).size).to eq(1)
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

    def create_reminder(invoice, reminder_type: "due_today", event_on: invoice.due_on, **attributes)
      invoice.billing_reminders.create!({
        business: invoice.business,
        reminder_type: reminder_type,
        channel: "email",
        recipient: invoice.business.owner.email_address,
        event_on: event_on,
        status: "pending"
      }.merge(attributes))
    end

    def enqueued_reminder_jobs_for(reminder)
      enqueued_jobs.select do |job|
        job.fetch(:job) == Billing::SendReminderJob && job.fetch(:args) == [ reminder.id ]
      end
    end
end
