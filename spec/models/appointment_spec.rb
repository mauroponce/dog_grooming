require "rails_helper"
require "cgi"
require "uri"

RSpec.describe Appointment, type: :model do
  describe "admin live updates" do
    it "broadcasts a refresh when a confirmed appointment is created" do
      business = create_business

      expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
        .with(*LiveStreams.admin_appointments(business))

      create_appointment(business)
    end

    it "broadcasts a refresh when an appointment becomes confirmed" do
      business = create_business
      appointment = create_appointment(business)
      appointment.update!(status: :pending)

      expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
        .with(*LiveStreams.admin_appointments(business))

      appointment.confirm!
    end

    it "does not broadcast a refresh for updates that do not confirm the appointment" do
      business = create_business
      appointment = create_appointment(business)
      appointment.update!(status: :pending)

      expect(Turbo::StreamsChannel).not_to receive(:broadcast_refresh_to)

      appointment.update!(customer_name: "Julieta Actualizada")
    end
  end

  describe "status presentation" do
    it "labels completed appointments as finalized with a violet tone" do
      expect(described_class.status_label("completed")).to eq("Finalizado")
      expect(described_class.status_tone("completed")).to eq(:violet)
    end
  end

  describe "short UUIDs" do
    it "assigns an opaque URL-safe identifier to every appointment" do
      appointment = create_appointment(create_business)

      expect(appointment.short_uuid).to match(/\A[A-Za-z0-9_-]{12}\z/)
      expect(appointment.short_uuid).not_to eq(appointment.id.to_s)
      expect(appointment.to_param).to eq(appointment.short_uuid)
    end
  end

  it "does not allow full-price payment mode for reservations" do
    business = create_business
    appointment = create_appointment(business)

    appointment.payment_charge_mode = "full_price"

    expect(appointment).not_to be_valid
    expect(appointment.errors[:payment_charge_mode]).to be_present
  end

  describe "#cancel!" do
    it "creates a booking cancellation notification for the business" do
      business = create_business
      appointment = create_appointment(business)

      expect {
        appointment.cancel!(by: "admin", reason: "El local permanece cerrado")
      }.to change { business.provider_events.where(event_type: "booking_cancelled").count }.by(1)

      event = business.provider_events.where(event_type: "booking_cancelled").last
      expect(event.title).to eq("Turno cancelado")
      expect(event.body).to include("Julieta Perez")
      expect(event.body).to include("Esmaltado")
      expect(event.body).to include("El local permanece cerrado")
      expect(event.metadata["appointment_id"]).to eq(appointment.id)
      expect(event.metadata["canceled_by"]).to eq("admin")
    end

    it "does not classify a cancellation from a standalone customer link as a portal cancellation" do
      business = create_business
      appointment = create_appointment(business)

      appointment.cancel!(by: "customer_link", reason: "Cancelado desde el enlace")

      expect(business.provider_events.last.event_type).to eq("booking_cancelled")
    end

    it "does not create duplicate notifications when the appointment is already canceled" do
      business = create_business
      appointment = create_appointment(business)
      appointment.cancel!(by: "admin")

      expect {
        appointment.cancel!(by: "customer_link")
      }.not_to change { business.provider_events.count }
    end
  end

  describe "#remaining_balance_cents" do
    it "uses the current service price instead of the price stored when the appointment was created" do
      business = create_business
      appointment = create_appointment(business)
      appointment.update!(base_price_cents: 12_000_00, final_price_cents: 12_000_00, deposit_amount_cents: 3_000_00)
      appointment.service.update!(price_cents: 14_000_00)

      expect(appointment.current_total_price_cents).to eq(14_000_00)
      expect(appointment.remaining_balance_cents).to eq(11_000_00)
    end
  end

  describe "remaining balance payments" do
    include ActiveSupport::Testing::TimeHelpers

    it "records the paid amount, timestamp, payer, and selected payment account" do
      travel_to Time.zone.local(2026, 8, 10, 14, 25) do
        business = create_business
        account = business.payment_accounts.create!(
          name: "Cuenta Banco Nación",
          details: "Alias: casa.tony"
        )
        appointment = create_appointment(business)
        appointment.service.update!(payment_account: account)
        appointment.mark_manual_deposit_pending!(amount_cents: 5_000_00)
        appointment.mark_deposit_approved!(reviewed_by: business.owner)

        appointment.mark_remaining_balance_paid!(paid_by: business.owner)

        expect(appointment).to be_remaining_balance_paid
        expect(appointment.remaining_balance_paid_cents).to eq(15_000_00)
        expect(appointment.remaining_balance_paid_at).to eq(Time.current)
        expect(appointment.remaining_balance_paid_by).to eq(business.owner)
        expect(appointment.remaining_balance_payment_method).to eq("Cuenta Banco Nación")
        expect(appointment.remaining_balance_cents).to eq(0)
        expect(appointment.deposit_paid_at).to eq(appointment.deposit_reviewed_at)
        expect(appointment.deposit_payment_method_label).to eq("Cuenta Banco Nación")
      end
    end

    it "does not allow recording a balance that is not payable" do
      appointment = create_appointment(create_business)
      appointment.cancel!(by: "admin")

      expect {
        appointment.mark_remaining_balance_paid!(paid_by: appointment.business.owner)
      }.to raise_error(ArgumentError, "El turno no tiene saldo pendiente para registrar.")
    end
  end

  describe "Google Calendar links" do
    it "enables the customer Google Calendar link only for Gmail addresses" do
      business = create_business
      customer = business.customer_profiles.create!(
        name: "Julieta Perez",
        phone: "+54 9 11 1111-1111",
        email: "julieta@gmail.com"
      )
      appointment = create_appointment(business, customer_profile: customer)

      expect(appointment.google_calendar_available_for_customer?).to be(true)
      expect(appointment.google_calendar_url).to include("https://calendar.google.com/calendar/u/0/r/eventedit")
      expect(CGI.unescape(appointment.google_calendar_url)).to include("text=Esmaltado - Casa Tony")
      expect(CGI.unescape(appointment.google_calendar_url)).to include("location=Av. Siempre Viva 123, Buenos Aires")
    end

    it "does not include the assigned professional in the customer calendar details" do
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

      calendar_url = CGI.unescape(appointment.google_calendar_url)

      expect(calendar_url).not_to include("Profesional:")
      expect(calendar_url).not_to include(employee.name)
    end

    it "does not enable the customer Google Calendar link for non-Gmail addresses" do
      business = create_business
      customer = business.customer_profiles.create!(
        name: "Julieta Perez",
        phone: "+54 9 11 1111-1111",
        email: "julieta@example.com"
      )
      appointment = create_appointment(business, customer_profile: customer)

      expect(appointment.google_calendar_available_for_customer?).to be(false)
    end

    it "uses the assigned professional Gmail address for professional calendar links" do
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

      expect(appointment.google_calendar_available_for_professional?).to be(true)
    end
  end

  def create_business
    owner = User.create!(
      email_address: "appointment-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )

    Business.create!(
      owner: owner,
      name: "Casa Tony",
      slug: "casa-tony-#{SecureRandom.hex(4)}",
      address: "Av. Siempre Viva 123",
      city: "Buenos Aires",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )
  end

  def create_appointment(business, customer_profile: nil, employee_membership: nil)
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

    starts_at = Time.zone.local(2026, 7, 24, 10, 0)
    business.appointments.create!(
      service: service,
      customer_profile: customer_profile,
      employee_membership: employee_membership,
      customer_name: customer_profile&.name || "Julieta Perez",
      customer_phone: customer_profile&.phone || "+54 9 11 1111-1111",
      customer_email: customer_profile&.email,
      starts_at: starts_at,
      status: :confirmed,
      source: :public_booking,
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )
  end
end

RSpec.describe CustomerDateFormatter do
  it "formats system dates with the Argentine numeric format" do
    starts_at = Time.zone.local(2026, 7, 25, 15, 30)

    expect(described_class.date_label(starts_at)).to eq("25/07/2026")
    expect(described_class.datetime_label(starts_at)).to eq("25/07/2026 15:30 hs")
    expect(described_class.appointment_label(starts_at)).to eq("25/07/2026 · 15:30 hs")
  end
end
