require "rails_helper"

RSpec.describe MercadoPago::CreateBookingPreference do
  it "creates a checkout preference for the sum of appointment deposits only" do
    business = create_business
    service = create_service(business, price_cents: 20_000_00)
    appointment = create_payment_pending_appointment(
      business: business,
      service: service,
      deposit_amount_cents: 4_000_00
    )
    client = instance_double(MercadoPago::Client)
    captured_payload = nil

    allow(MercadoPago::Credentials).to receive(:test?).and_return(false)
    allow(MercadoPago::Client).to receive(:new).with(connection: business.mercado_pago_connection).and_return(client)
    allow(client).to receive(:create_preference!) do |payload|
      captured_payload = payload
      {
        "id" => "pref-123",
        "init_point" => "https://www.mercadopago.com.ar/checkout/v1/redirect?pref_id=pref-123",
        "sandbox_init_point" => "https://sandbox.mercadopago.com.ar/checkout/v1/redirect?pref_id=pref-123"
      }
    end

    payment = described_class.call(appointments: [ appointment ], host: "51d9-187-61-184-88.ngrok-free.app", protocol: "https")

    expect(payment).to be_persisted
    expect(payment.amount_cents).to eq(4_000_00)
    expect(payment.appointment).to eq(appointment)
    expect(payment.appointment_ids).to eq([ appointment.id ])
    expect(payment.preference_id).to eq("pref-123")
    expect(captured_payload.dig(:items, 0, :unit_price)).to eq(4_000.0)
    expect(captured_payload.dig(:items, 0, :title)).to eq("Reserva Esmaltado - MP Test Center")
    expect(captured_payload.dig(:metadata, :appointment_ids)).to eq([ appointment.id ])
    expect(captured_payload.dig(:metadata, :external_reference)).to eq(payment.external_reference)
    expect(captured_payload[:auto_return]).to eq("approved")
    expect(captured_payload.dig(:back_urls, :success)).to start_with("https://51d9-187-61-184-88.ngrok-free.app/#{business.slug}?")
    expect(captured_payload.dig(:back_urls, :success)).to include("confirmation=")
    expect(captured_payload.dig(:back_urls, :success)).to include("&mp_status=success")
    expect(captured_payload.dig(:back_urls, :pending)).to include("&mp_status=pending")
    expect(captured_payload.dig(:back_urls, :failure)).to include("&mp_status=failure")
    expect(captured_payload[:notification_url]).to start_with("https://51d9-187-61-184-88.ngrok-free.app/webhooks/mercado-pago")
  end

  it "omits the payer payload when the customer email is blank" do
    business = create_business
    service = create_service(business, price_cents: 20_000_00)
    appointment = create_payment_pending_appointment(
      business: business,
      service: service,
      deposit_amount_cents: 4_000_00,
      customer_email: nil
    )
    client = instance_double(MercadoPago::Client)
    captured_payload = nil

    allow(MercadoPago::Credentials).to receive(:test?).and_return(false)
    allow(MercadoPago::Client).to receive(:new).with(connection: business.mercado_pago_connection).and_return(client)
    allow(client).to receive(:create_preference!) do |payload|
      captured_payload = payload
      {
        "id" => "pref-blank-email",
        "init_point" => "https://www.mercadopago.com.ar/checkout/v1/redirect?pref_id=pref-blank-email",
        "sandbox_init_point" => "https://sandbox.mercadopago.com.ar/checkout/v1/redirect?pref_id=pref-blank-email"
      }
    end

    described_class.call(appointments: [ appointment ], host: "51d9-187-61-184-88.ngrok-free.app", protocol: "https")

    expect(captured_payload).not_to have_key(:payer)
  end

  it "uses the app test access token for local Mercado Pago checkout preferences" do
    business = create_business
    service = create_service(business, price_cents: 20_000_00)
    appointment = create_payment_pending_appointment(
      business: business,
      service: service,
      deposit_amount_cents: 4_000_00
    )
    client = instance_double(MercadoPago::Client)

    allow(MercadoPago::Credentials).to receive(:test?).and_return(true)
    allow(MercadoPago::Credentials).to receive(:access_token).and_return("APP_USR-test-checkout-token")
    expect(MercadoPago::Client).to receive(:new).with(access_token: "APP_USR-test-checkout-token").and_return(client)
    allow(client).to receive(:create_preference!).and_return(
      {
        "id" => "pref-test-token",
        "init_point" => "https://www.mercadopago.com.ar/checkout/v1/redirect?pref_id=pref-test-token",
        "sandbox_init_point" => "https://sandbox.mercadopago.com.ar/checkout/v1/redirect?pref_id=pref-test-token"
      }
    )

    payment = described_class.call(appointments: [ appointment ], host: "51d9-187-61-184-88.ngrok-free.app", protocol: "https")

    expect(payment.preference_id).to eq("pref-test-token")
  end

  it "rejects a test OAuth connection when creating a production checkout" do
    business = create_business
    service = create_service(business, price_cents: 20_000_00)
    appointment = create_payment_pending_appointment(
      business: business,
      service: service,
      deposit_amount_cents: 4_000_00
    )
    business.mercado_pago_connection.update!(metadata: { "live_mode" => false })

    allow(MercadoPago::Credentials).to receive(:test?).and_return(false)

    expect {
      described_class.call(appointments: [ appointment ], host: "cita.pet", protocol: "https")
    }.to raise_error(ArgumentError, /conectada en modo prueba/)
  end

  def create_business
    owner = User.create!(
      email_address: "mp-pref-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )

    Business.create!(
      owner: owner,
      name: "MP Test Center",
      slug: "mp-test-center-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current,
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "mercado_pago" ]
      }
    ).tap do |business|
      business.create_mercado_pago_connection!(
        access_token: "APP_USR-test-token",
        refresh_token: "refresh-token",
        mercado_pago_user_id: "123",
        connected_at: Time.current
      )
    end
  end

  def create_service(business, price_cents:)
    business.services.create!(
      name: "Esmaltado",
      category: "Uñas",
      duration_minutes: 30,
      price_cents: price_cents,
      active: true,
      public_visible: true,
      visibility_mode: "public",
      deposit_required: true,
      deposit_amount_cents: 4_000_00
    )
  end

  def create_payment_pending_appointment(business:, service:, deposit_amount_cents:, customer_email: "julieta@example.com")
    starts_at = 2.days.from_now.change(hour: 10, min: 0, sec: 0)
    business.appointments.create!(
      service: service,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111",
      customer_email: customer_email,
      starts_at: starts_at,
      ends_at: starts_at + service.duration_minutes.minutes,
      status: :pending_payment,
      source: :public_booking,
      deposit_status: "pending",
      deposit_amount_cents: deposit_amount_cents,
      payment_collection_method: "mercado_pago",
      payment_charge_mode: "deposit",
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )
  end
end
