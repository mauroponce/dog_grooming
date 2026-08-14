require "rails_helper"

RSpec.describe SendAppointmentReservedMessageJob do
  it "always emails the admin access address for a public booking" do
    appointment = create_public_booking(email_new_booking: false)
    delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)

    expect(AppointmentMailer).to receive(:new_booking).with(appointment).and_return(delivery)

    described_class.perform_now(appointment)
    described_class.perform_now(appointment)

    expect(delivery).to have_received(:deliver_later).once
    expect(appointment.notification_deliveries.where(template: "new_booking")).to contain_exactly(
      have_attributes(
        channel: "email",
        recipient: appointment.business.owner.email_address,
        status: "queued"
      )
    )
  end

  private
    def create_public_booking(email_new_booking:)
      owner = User.create!(
        email_address: "access-admin-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :admin
      )
      business = Business.create!(
        owner: owner,
        name: "Aura Estética",
        slug: "aura-estetica-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-5555",
        email_new_booking: email_new_booking,
        onboarding_completed_at: Time.current
      )
      service = business.services.create!(
        name: "Depilación",
        slug: "depilacion-#{SecureRandom.hex(4)}",
        duration_minutes: 30,
        price_cents: 12_000_00,
        active: true,
        public_visible: true,
        visibility_mode: "public"
      )
      starts_at = 2.days.from_now.change(hour: 11, min: 0, sec: 0)

      business.appointments.create!(
        service: service,
        customer_name: "Valentina Gómez",
        customer_phone: "+54 9 11 2222-2222",
        customer_email: "valentina-#{SecureRandom.hex(4)}@example.com",
        starts_at: starts_at,
        ends_at: starts_at + service.duration_minutes.minutes,
        source: :public_booking,
        status: :confirmed,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )
    end
end
