require "rails_helper"

RSpec.describe BusinessMailer, type: :mailer do
  include ActiveSupport::Testing::TimeHelpers

  it "renders the daily digest without the removed waitlist schema" do
    travel_to Time.zone.local(2026, 10, 19, 10, 0, 0) do
      owner = User.create!(email_address: "daily-digest-#{SecureRandom.hex(4)}@example.test", role: :admin)
      business = Business.create!(
        owner: owner,
        name: "Resumen Test",
        slug: "resumen-test-#{SecureRandom.hex(4)}",
        onboarding_completed_at: Time.current,
        email_daily_digest: true
      )
      business.availability_rules.find_by!(weekday: Time.zone.today.wday).update!(active: true, start_time: "09:00", end_time: "18:00")
      business.services.create!(
        name: "Baño",
        category: "Baño",
        duration_minutes: 60,
        price_cents: 20_000_00,
        active: true,
        public_visible: true,
        visibility_mode: "public"
      )

      mail = described_class.daily_digest(business)

      expect(mail.to).to eq([ owner.email_address ])
      expect(mail.subject).to eq("Resumen de hoy en Cita.pet")
      expect(mail.body.encoded).to include("Huecos para ofrecer")
    end
  end

  it "renders the legacy Mercado Pago confirmation with its calendar link" do
    appointment = create_mercado_pago_appointment

    mail = described_class.booking_confirmed_by_mercado_pago(appointment)

    expect(mail.to).to eq([ appointment.business.owner.email_address ])
    expect(mail.subject).to eq("Turno confirmado con pago de Mercado Pago")
    expect(mail.html_part.body.decoded).to include("Mercado Pago", "calendar.google.com")
    expect(mail.text_part.body.decoded).to include(appointment.formatted_deposit_amount)
  end

  private
    def create_mercado_pago_appointment
      owner = User.create!(
        email_address: "business-mailer-owner-#{SecureRandom.hex(4)}@example.test",
        role: :admin
      )
      business = Business.create!(
        owner: owner,
        name: "Aura MP",
        slug: "aura-mp-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-5555",
        onboarding_completed_at: Time.current
      )
      service = business.services.create!(
        name: "Baño",
        duration_minutes: 30,
        price_cents: 20_000_00,
        active: true,
        public_visible: true,
        visibility_mode: "public",
        deposit_required: true,
        deposit_amount_cents: 5_000_00
      )
      starts_at = 2.days.from_now.change(hour: 11, min: 0, sec: 0)

      business.appointments.create!(
        service: service,
        customer_name: "Julieta Pérez",
        customer_phone: "+54 9 11 2222-2222",
        customer_email: "julieta-#{SecureRandom.hex(4)}@example.test",
        starts_at: starts_at,
        ends_at: starts_at + 30.minutes,
        source: :public_booking,
        status: :confirmed,
        deposit_status: "approved",
        deposit_amount_cents: 5_000_00,
        payment_collection_method: "mercado_pago",
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )
    end
end
