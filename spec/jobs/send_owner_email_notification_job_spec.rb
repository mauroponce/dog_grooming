require "rails_helper"

RSpec.describe SendOwnerEmailNotificationJob do
  it "emails both parties once when the customer cancels from the portal" do
    appointment = create_appointment
    event = appointment.business.provider_events.create!(
      event_type: "customer_cancelled_booking",
      title: "Cliente canceló un turno",
      metadata: { appointment_id: appointment.id }
    )
    business_delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
    customer_delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)

    expect(BusinessMailer).to receive(:booking_cancelled).with(appointment).and_return(business_delivery)
    expect(AppointmentMailer).to receive(:customer_booking_cancelled).with(appointment).and_return(customer_delivery)

    described_class.perform_now(event.id)
    described_class.perform_now(event.id)

    expect(business_delivery).to have_received(:deliver_later).once
    expect(customer_delivery).to have_received(:deliver_later).once
    expect(appointment.notification_deliveries.where(channel: "email").pluck(:template)).to contain_exactly(
      "business_booking_cancelled",
      "customer_booking_cancelled"
    )
  end

  it "emails the customer when the business cancels the booking" do
    appointment = create_appointment
    appointment.cancel!(by: appointment.business.owner, reason: "El centro no abrirá ese día")
    event = appointment.business.provider_events.order(:created_at).last
    customer_delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)

    expect(BusinessMailer).not_to receive(:booking_cancelled)
    expect(AppointmentMailer).to receive(:customer_booking_cancelled).with(appointment).and_return(customer_delivery)

    described_class.perform_now(event.id)

    expect(customer_delivery).to have_received(:deliver_later).once
    expect(appointment.notification_deliveries.where(channel: "email").pluck(:template)).to contain_exactly(
      "customer_booking_cancelled"
    )
  end

  private
    def create_appointment
      owner = User.create!(email_address: "cancellation-owner-#{SecureRandom.hex(4)}@example.com", password: "password123")
      business = Business.create!(owner: owner, name: "Aura Cancelación", slug: "aura-cancelacion-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-5555", onboarding_completed_at: Time.current)
      service = business.services.create!(name: "Láser", slug: "laser-cancelacion-#{SecureRandom.hex(4)}", duration_minutes: 30, price_cents: 20_000_00, active: true, public_visible: true, visibility_mode: "public")
      starts_at = 2.days.from_now.change(hour: 11, min: 0, sec: 0)
      business.appointments.create!(service: service, customer_name: "Julieta Pérez", customer_phone: "+54 9 11 2222-2222", customer_email: "julieta-#{SecureRandom.hex(4)}@example.com", starts_at: starts_at, ends_at: starts_at + 30.minutes, source: :public_booking, status: :confirmed, base_price_cents: service.price_cents, final_price_cents: service.price_cents)
    end
end
