require "rails_helper"

RSpec.describe SendAppointmentReminderJob do
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
      starts_at = 2.days.from_now.change(hour: 11, min: 0, sec: 0)
      business.appointments.create!(service: service, customer_name: "Julieta Pérez", customer_phone: "+54 9 11 2222-2222", customer_email: "julieta-#{SecureRandom.hex(4)}@example.com", starts_at: starts_at, ends_at: starts_at + 30.minutes, source: :public_booking, status: :confirmed, base_price_cents: service.price_cents, final_price_cents: service.price_cents)
    end
end
