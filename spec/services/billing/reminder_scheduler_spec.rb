require "rails_helper"

RSpec.describe Billing::ReminderScheduler do
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

  it "keeps a failed reminder retryable when enqueueing fails" do
    reminder = create_reminder
    allow(Billing::SendReminderJob).to receive(:new).and_raise(ActiveJob::EnqueueError, "queue unavailable")

    described_class.new.schedule!(reminder.subscription_invoice, reminder.reminder_type, event_on: reminder.event_on)

    expect(reminder.reload).to have_attributes(status: "failed", sent_at: nil, enqueued_at: nil, active_job_id: nil)
  end

  it "does not duplicate a recently enqueued job" do
    reminder = create_reminder(enqueued_at: 5.minutes.ago, active_job_id: SecureRandom.uuid)

    described_class.new.recover_stale!

    expect(enqueued_reminder_jobs_for(reminder)).to be_empty
  end

  it "leaves a stale reminder alone while its Solid Queue job remains active" do
    reminder = create_reminder(enqueued_at: 2.hours.ago, active_job_id: SecureRandom.uuid)
    scheduler = described_class.new
    allow(scheduler).to receive(:active_job_present?).with(reminder.active_job_id).and_return(true)

    scheduler.recover_stale!

    expect(reminder.reload.active_job_id).to be_present
    expect(enqueued_reminder_jobs_for(reminder)).to be_empty
  end

  it "recovers a stale reminder after its Solid Queue job disappears without duplicating it" do
    missing_job_id = SecureRandom.uuid
    reminder = create_reminder(enqueued_at: 2.hours.ago, active_job_id: missing_job_id)
    scheduler = described_class.new
    allow(scheduler).to receive(:active_job_present?).with(missing_job_id).and_return(false)

    scheduler.recover_stale!
    scheduler.recover_stale!

    expect(reminder.reload).to have_attributes(status: "pending")
    expect(reminder.active_job_id).to be_present
    expect(reminder.active_job_id).not_to eq(missing_job_id)
    expect(enqueued_reminder_jobs_for(reminder).size).to eq(1)
  end

  it "recovers a failed delivery after Active Job has no active retry" do
    failed_job_id = SecureRandom.uuid
    reminder = create_reminder(
      status: "failed",
      enqueued_at: 2.hours.ago,
      active_job_id: failed_job_id,
      updated_at: 2.hours.ago
    )
    scheduler = described_class.new
    allow(scheduler).to receive(:active_job_present?).with(failed_job_id).and_return(false)

    scheduler.recover_stale!
    scheduler.recover_stale!

    expect(reminder.reload.status).to eq("pending")
    expect(reminder.active_job_id).not_to eq(failed_job_id)
    expect(enqueued_reminder_jobs_for(reminder).size).to eq(1)
  end

  private
    def create_reminder(**attributes)
      owner = User.create!(
        email_address: "scheduler-owner-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :admin
      )
      business = Business.create!(
        owner: owner,
        name: "Centro Scheduler",
        slug: "centro-scheduler-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-1234",
        onboarding_completed_at: Time.current
      )
      invoice = business.subscription.subscription_invoices.create!(
        business: business,
        period_start: Time.zone.today,
        period_end: 1.month.from_now.to_date,
        billing_period_months: 1,
        amount_cents: business.monthly_amount_cents,
        due_on: Time.zone.today,
        reference_code: "HT-SCHEDULER-#{SecureRandom.hex(4).upcase}",
        status: "open"
      )
      invoice.billing_reminders.create!({
        business: business,
        reminder_type: "due_today",
        channel: "email",
        recipient: owner.email_address,
        event_on: Time.zone.today,
        status: "pending"
      }.merge(attributes))
    end

    def enqueued_reminder_jobs_for(reminder)
      enqueued_jobs.select do |job|
        job.fetch(:job) == Billing::SendReminderJob && job.fetch(:args) == [ reminder.id ]
      end
    end
end
