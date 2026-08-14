require "rails_helper"

RSpec.describe WhatsApp::MessageBuilder do
  describe "#message" do
    it "uses the requested customer confirmation message" do
      business = create_business
      customer = create_customer(business, email: "juli@gmail.com")
      appointment = create_appointment(business, customer)

      message = described_class.new(
        business: business,
        template_key: "booking_confirmation",
        booking: appointment,
        customer: customer,
        service: appointment.service,
        professional: appointment.employee_membership
      ).message

      expect(message).to eq([
        "Hola Julieta Perez,",
        "✅ Turno confirmado con #{business.name}",
        "Servicio: Esmaltado",
        "Fecha y hora: #{appointment.starts_at.in_time_zone.strftime('%d/%m/%Y, %H:%Mhs')}",
        "Podes gestionar tus turnos aca: #{customer.customer_portal_url}"
      ].join("\n"))
    end

    it "does not add a Google Calendar link to booking confirmations for non-Gmail customers" do
      business = create_business
      customer = create_customer(business, email: "juli@example.com")
      appointment = create_appointment(business, customer)

      message = described_class.new(
        business: business,
        template_key: "booking_confirmation",
        booking: appointment,
        customer: customer,
        service: appointment.service,
        professional: appointment.employee_membership
      ).message

      expect(message).to include(customer.customer_portal_url)
      expect(message).not_to include("Google Calendar")
      expect(message).not_to include("calendar.google.com")
    end
  end

  def create_business
    owner = User.create!(
      email_address: "whatsapp-builder-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )

    Business.create!(
      owner: owner,
      name: "Casa Tony",
      slug: "casa-tony-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )
  end

  def create_customer(business, email:)
    business.customer_profiles.create!(
      name: "Julieta Perez",
      phone: "+54 9 11 1111-1111",
      email: email
    )
  end

  def create_appointment(business, customer)
    service = business.services.create!(
      name: "Esmaltado",
      slug: "esmaltado-#{SecureRandom.hex(3)}",
      category: "Beauty Nails",
      duration_minutes: 30,
      price_cents: 20_000_00,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )

    business.appointments.create!(
      service: service,
      customer_profile: customer,
      customer_name: customer.name,
      customer_phone: customer.phone,
      customer_email: customer.email,
      starts_at: 3.days.from_now.change(hour: 10, min: 0, sec: 0),
      status: :confirmed,
      source: :public_booking,
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )
  end
end
