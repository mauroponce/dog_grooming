require "rails_helper"

RSpec.describe SendAppointmentReminderJob do
  include ActiveJob::TestHelper
  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it "does not email cancelled, past, distant or email-less appointments" do
    appointment = create_appointment
    expect(AppointmentMailer).not_to receive(:customer_reminder)
    appointment.update!(status: :canceled)
    described_class.perform_now(appointment)
    appointment.update!(status: :confirmed, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 30.minutes)
    described_class.perform_now(appointment)
    appointment.update!(starts_at: 1.day.ago, ends_at: 1.day.ago + 30.minutes)
    described_class.perform_now(appointment)
    appointment.update!(starts_at: 12.hours.from_now, ends_at: 12.hours.from_now + 30.minutes, customer_email: nil)
    described_class.perform_now(appointment)
    expect(appointment.reload.reminder_sent_at).to be_nil
  end

  it "remains retryable if delivery fails" do
    appointment = create_appointment
    delivery = instance_double(ActionMailer::MessageDelivery)
    allow(AppointmentMailer).to receive(:customer_reminder).and_return(delivery)
    allow(delivery).to receive(:deliver_now).and_raise(RuntimeError, "SMTP unavailable")
    expect { described_class.perform_now(appointment) }.to raise_error(RuntimeError)
    expect(appointment.reload.reminder_sent_at).to be_nil
    expect(appointment.notification_deliveries).to be_empty
    allow(delivery).to receive(:deliver_now).and_return(true)
    described_class.perform_now(appointment)
    expect(appointment.reload.reminder_sent_at).to be_present
  end

  it "queues a reminder when a last-minute booking is confirmed and when a due scan runs" do
    appointment = create_appointment
    clear_enqueued_jobs
    appointment.update!(status: :pending)
    expect { appointment.confirm! }.to have_enqueued_job(described_class).with(appointment)
    clear_enqueued_jobs
    expect { SendDueAppointmentRemindersJob.perform_now }.to have_enqueued_job(described_class).with(appointment)
    appointment.update!(reminder_sent_at: Time.current)
    clear_enqueued_jobs
    expect { SendDueAppointmentRemindersJob.perform_now }.not_to have_enqueued_job(described_class)
  end

  it "renders an email with booking-only access and no internal profile information" do
    appointment = create_appointment
    customer = appointment.business.customer_profiles.create!(name: "Ana", phone: "1199999999", internal_notes: "Secret internal note")
    appointment.update!(customer_profile: customer)
    mail = AppointmentMailer.customer_reminder(appointment)
    expect(mail.to).to eq([ appointment.customer_email ])
    expect(mail.html_part.body.decoded).to include("confirmation=")
    expect(mail.html_part.body.decoded).not_to include("Secret internal note", "/mis-turnos/")
  end

  it "rechecks the new schedule and resets the reminder when a sent appointment is rescheduled" do
    appointment = create_appointment
    appointment.update!(reminder_sent_at: Time.current)
    appointment.update!(starts_at: 3.days.from_now, ends_at: 3.days.from_now + 30.minutes)
    expect(appointment.reload.reminder_sent_at).to be_nil
    expect(AppointmentMailer).not_to receive(:customer_reminder)
    described_class.perform_now(appointment)
  end

  it "sends the email reminder once and records the delivery timestamp" do
    appointment = create_appointment
    delivery = instance_double(ActionMailer::MessageDelivery, deliver_now: true)

    expect(AppointmentMailer).to receive(:customer_reminder).with(appointment).and_return(delivery)

    described_class.perform_now(appointment)
    described_class.perform_now(appointment)

    expect(delivery).to have_received(:deliver_now).once
    expect(appointment.reload.reminder_sent_at).to be_present
  end

  private
    def create_appointment
      owner = User.create!(email_address: "reminder-owner-#{SecureRandom.hex(4)}@example.com", password: "password123")
      business = Business.create!(owner: owner, name: "Aura Reminder", slug: "aura-reminder-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-5555", onboarding_completed_at: Time.current)
      service = business.services.create!(name: "Láser", slug: "laser-reminder-#{SecureRandom.hex(4)}", duration_minutes: 30, price_cents: 20_000_00, active: true, public_visible: true, visibility_mode: "public")
      starts_at = 12.hours.from_now
      business.appointments.create!(service: service, customer_name: "Julieta Pérez", customer_phone: "+54 9 11 2222-2222", customer_email: "julieta-#{SecureRandom.hex(4)}@example.com", starts_at: starts_at, ends_at: starts_at + 30.minutes, source: :public_booking, status: :confirmed, base_price_cents: service.price_cents, final_price_cents: service.price_cents)
    end
end
