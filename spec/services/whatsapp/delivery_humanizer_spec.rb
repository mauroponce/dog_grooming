require "rails_helper"

RSpec.describe WhatsApp::DeliveryHumanizer do
  describe ".owner_notification_text" do
    it "uses one deterministic message for a confirmed booking" do
      business = create_business
      employee = business.employee_memberships.create!(
        first_name: "Jennifer",
        last_name: "Lopez",
        name: "Jennifer Lopez",
        email_address: "jennifer@example.com",
        status: "active",
        can_receive_appointments: true
      )
      appointment = create_appointment(business, employee_membership: employee)
      event = Struct.new(:body, :title).new("Nueva reserva", "Reserva")
      action_url = "https://dog-grooming.example.com/admin/calendario?t=#{appointment.short_uuid}"
      date_and_time = appointment.starts_at.in_time_zone.strftime("%d/%m/%Y, %H:%Mhs")

      text = described_class.owner_notification_text(
        business: business,
        event: event,
        template_key: "pending_booking",
        appointment: appointment,
        action_url: action_url
      )

      expect(text).to eq([
        "✅ Nuevo turno confirmado",
        "Cliente: Julieta Perez - +5491111111111",
        "Servicio: Esmaltado",
        "Profesional: Jennifer Lopez",
        "Fecha y hora: #{date_and_time}",
        "Ver turno: #{action_url}"
      ].join("\n"))
    end

    it "includes the customer appointment history link in a cancellation notification" do
      business = create_business
      employee = business.employee_memberships.create!(
        first_name: "Jennifer",
        last_name: "Lopez",
        name: "Jennifer Lopez",
        email_address: "jennifer@example.com",
        status: "active",
        can_receive_appointments: true
      )
      appointment = create_appointment(business, employee_membership: employee)
      event = Struct.new(:body, :title).new("Cancelación", "Turno cancelado")
      date_and_time = appointment.starts_at.in_time_zone.strftime("%d/%m/%Y, %H:%Mhs")

      action_url = "https://dog-grooming.example.com/admin/clientes/39/editar#turnos"
      text = described_class.owner_notification_text(
        business: business,
        event: event,
        template_key: "booking_cancelled",
        appointment: appointment,
        action_url: action_url
      )

      expect(text).to eq([
        "❌ Turno cancelado",
        "Cliente: Julieta Perez - +5491111111111",
        "Servicio: Esmaltado",
        "Profesional: Jennifer Lopez",
        "Fecha y hora: #{date_and_time}",
        "Ver turno: #{action_url}"
      ].join("\n"))
    end

    it "does not add a Google Calendar link when the assigned professional has Gmail" do
      business = create_business
      employee = business.employee_memberships.create!(
        first_name: "Jennifer",
        last_name: "Lopez",
        name: "Jennifer Lopez",
        email_address: "jennifer@gmail.com",
        status: "active",
        can_receive_appointments: true
      )
      appointment = create_appointment(business, employee_membership: employee)
      event = Struct.new(:body, :title).new("Nueva reserva", "Reserva")

      text = described_class.owner_notification_text(
        business: business,
        event: event,
        template_key: "pending_booking",
        appointment: appointment,
        action_url: "http://localhost:3000/admin/calendario"
      )

      expect(text).not_to include("Agregar a Google Calendar")
      expect(text).not_to include("calendar.google.com")
    end

    it "does not add a Google Calendar link when the assigned professional is not Gmail" do
      business = create_business
      employee = business.employee_memberships.create!(
        first_name: "Jennifer",
        last_name: "Lopez",
        name: "Jennifer Lopez",
        email_address: "jennifer@example.com",
        status: "active",
        can_receive_appointments: true
      )
      appointment = create_appointment(business, employee_membership: employee)
      event = Struct.new(:body, :title).new("Nueva reserva", "Reserva")

      text = described_class.owner_notification_text(
        business: business,
        event: event,
        template_key: "pending_booking",
        appointment: appointment,
        action_url: "http://localhost:3000/admin/calendario"
      )

      expect(text).not_to include("Google Calendar")
      expect(text).not_to include("calendar.google.com")
    end
  end

  def create_business
    owner = User.create!(
      email_address: "delivery-owner-#{SecureRandom.hex(4)}@example.com",
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

  def create_appointment(business, employee_membership:)
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
      employee_membership: employee_membership,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111",
      starts_at: 3.days.from_now.change(hour: 10, min: 0, sec: 0),
      status: :confirmed,
      source: :public_booking,
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )
  end
end
