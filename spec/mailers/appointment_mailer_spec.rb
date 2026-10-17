require "rails_helper"

RSpec.describe AppointmentMailer, type: :mailer do
  it "renders a customer reminder with calendar and booking-detail links" do
    appointment = create_appointment

    mail = described_class.customer_reminder(appointment)

    expect(mail.to).to eq([ appointment.customer_email ])
    expect(mail.subject).to eq("Recordatorio de tu turno en #{appointment.business.name}")
    expect(mail.html_part.body.decoded).to include("calendar.google.com")
    expect(mail.html_part.body.decoded).to include("confirmation=")
    expect(mail.html_part.body.decoded).to include("Ver detalle de mi turno")
    expect(mail.html_part.body.decoded).not_to include("portal")
  end

  it "renders the admin new-booking email without exposing internal customer notes" do
    appointment = create_appointment
    appointment.update!(internal_notes: "Nota privada")

    mail = described_class.new_booking(appointment)

    expect(mail.to).to eq([ appointment.business.owner.email_address ])
    expect(mail.subject).to eq("Nueva reserva para revisar")
    expect(mail.html_part.body.decoded).to include(appointment.customer_name, appointment.service.name)
    expect(mail.html_part.body.decoded).not_to include("Nota privada")
  end

  private
    def create_appointment
      owner = User.create!(email_address: "mailer-owner-#{SecureRandom.hex(4)}@example.test", role: :admin)
      business = Business.create!(
        owner: owner,
        name: "Patitas Mailer",
        slug: "patitas-mailer-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-5555",
        onboarding_completed_at: Time.current
      )
      service = business.services.create!(
        name: "Baño",
        category: "Baño",
        duration_minutes: 60,
        price_cents: 20_000_00,
        active: true,
        public_visible: true,
        visibility_mode: "public"
      )
      starts_at = 12.hours.from_now
      business.appointments.create!(
        service: service,
        customer_name: "Julieta Pérez",
        customer_phone: "+54 9 11 2222-2222",
        customer_email: "julieta-#{SecureRandom.hex(4)}@example.test",
        starts_at: starts_at,
        ends_at: starts_at + 60.minutes,
        source: :public_booking,
        status: :confirmed,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )
    end
end
