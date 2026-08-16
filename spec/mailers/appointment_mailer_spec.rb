require "rails_helper"

RSpec.describe AppointmentMailer, type: :mailer do
  it "renders the confirmed-booking email with Calendar, portal, and Cita.pet logo" do
    appointment = create_appointment

    mail = described_class.customer_booking_confirmed(appointment)

    expect(mail.to).to eq([ appointment.customer_email ])
    expect(mail.subject).to eq("Tu turno en #{appointment.business.name} está confirmado")
    expect(mail.html_part.body.decoded).to include("/icon.png")
    expect(mail.html_part.body.decoded).to include("calendar.google.com")
    expect(mail.html_part.body.decoded).to include(appointment.customer_portal_booking_url)
    expect(mail.text_part.body.decoded).to include("Agregar a Google Calendar")
    expect(mail.text_part.body.decoded).to include("Ver o reprogramar mi turno")
  end

  it "renders cancellation and reminder emails for the customer" do
    appointment = create_appointment

    cancellation = described_class.customer_booking_cancelled(appointment)
    reminder = described_class.customer_reminder(appointment)

    expect(cancellation.subject).to include("fue cancelado")
    expect(cancellation.html_part.body.decoded).to include(appointment.service.name)
    expect(reminder.subject).to include("es mañana")
    expect(reminder.html_part.body.decoded).to include("calendar.google.com")
    expect(reminder.html_part.body.decoded).to include(appointment.customer_portal_booking_url)
  end

  it "tells the customer that the team will contact them when the business cancels" do
    appointment = create_appointment
    appointment.cancel!(by: appointment.business.owner, reason: "El centro no abrirá ese día")

    mail = described_class.customer_booking_cancelled(appointment)

    expect(mail.html_part.body.decoded).to include("El centro no abrirá ese día")
    expect(mail.html_part.body.decoded).to include("Alguien del equipo se va a estar comunicando con vos")
    expect(mail.text_part.body.decoded).to include("El centro no abrirá ese día")
    expect(mail.text_part.body.decoded).to include("Alguien del equipo se va a estar comunicando con vos")
  end

  private
    def create_appointment
      owner = User.create!(
        email_address: "mailer-owner-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :admin
      )
      business = Business.create!(
        owner: owner,
        name: "Aura Mailer",
        slug: "aura-mailer-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-5555",
        onboarding_completed_at: Time.current
      )
      service = business.services.create!(
        name: "Depilación",
        slug: "depilacion-mailer-#{SecureRandom.hex(4)}",
        duration_minutes: 30,
        price_cents: 12_000_00,
        active: true,
        public_visible: true,
        visibility_mode: "public"
      )
      customer = business.customer_profiles.create!(
        name: "Julieta Pérez",
        phone: "+54 9 11 2222-2222",
        email: "julieta-#{SecureRandom.hex(4)}@example.com"
      )
      starts_at = 2.days.from_now.change(hour: 11, min: 0, sec: 0)

      business.appointments.create!(
        service: service,
        customer_profile: customer,
        customer_name: customer.name,
        customer_phone: customer.phone,
        customer_email: customer.email,
        starts_at: starts_at,
        ends_at: starts_at + 30.minutes,
        source: :public_booking,
        status: :confirmed,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )
    end
end
