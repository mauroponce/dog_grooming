require "rails_helper"

RSpec.describe MercadoPago::ProcessWebhookJob do
  it "approves pending appointments when Mercado Pago approves the deposit" do
    business = create_business
    business.create_mercado_pago_connection!(
      access_token: "APP_USR-test-token",
      mercado_pago_email: "mp-owner@example.com",
      connected_at: Time.current
    )
    service = create_service(business)
    starts_at = 2.days.from_now.change(hour: 10, min: 0, sec: 0)
    appointment = create_pending_payment_appointment(
      business: business,
      service: service,
      starts_at: starts_at,
      deposit_amount_cents: 5_000_00
    )
    payment = AppointmentPayment.create!(
      business: business,
      appointment: appointment,
      amount_cents: 5_000_00,
      external_reference: "mp-approved-reference"
    )
    client = instance_double(
      MercadoPago::Client,
      fetch_payment!: {
        "id" => "123456",
        "status" => "approved",
        "external_reference" => payment.external_reference
      }
    )

    allow(MercadoPago::Client).to receive(:new).and_return(client)
    expect(SendCustomerBookingConfirmationJob).to receive(:perform_later).with(appointment)

    described_class.perform_now(
      payload: { "type" => "payment", "data" => { "id" => "123456" } },
      params: { "reference" => payment.external_reference }
    )

    expect(appointment.reload).to be_confirmed
    expect(appointment.deposit_status).to eq("approved")
    expect(appointment.payment_charge_mode).to eq("deposit")
    expect(appointment.remaining_balance_cents).to eq(15_000_00)
    expect(payment.reload).to be_approved
    event = business.provider_events.find_by!(event_type: "new_booking")
    expect(event.title).to eq("Nuevo turno confirmado")
    expect(event.metadata["appointment_id"]).to eq(appointment.id)
    expect(Admin::NotificationItem.new(event).notification_type).to eq("new_booking")

    legacy_event = ProviderEvent.new(
      business: business,
      event_type: "mercado_pago_payment_approved",
      title: "Pago aprobado en Mercado Pago"
    )
    expect(Admin::NotificationItem.new(legacy_event).notification_type).to eq("new_booking")
  end

  it "cancels pending appointments when Mercado Pago rejects the payment" do
    business = create_business
    business.create_mercado_pago_connection!(
      access_token: "APP_USR-test-token",
      mercado_pago_email: "mp-owner@example.com",
      connected_at: Time.current
    )
    service = create_service(business)
    starts_at = 2.days.from_now.change(hour: 10, min: 0, sec: 0)
    appointment = create_pending_payment_appointment(
      business: business,
      service: service,
      starts_at: starts_at,
      deposit_amount_cents: 5_000_00
    )
    payment = AppointmentPayment.create!(
      business: business,
      appointment: appointment,
      amount_cents: 5_000_00,
      external_reference: "mp-test-reference"
    )
    client = instance_double(
      MercadoPago::Client,
      fetch_payment!: {
        "id" => "123456",
        "status" => "rejected",
        "external_reference" => payment.external_reference
      }
    )

    allow(MercadoPago::Client).to receive(:new).and_return(client)

    described_class.perform_now(
      payload: { "type" => "payment", "data" => { "id" => "123456" } },
      params: { "reference" => payment.external_reference }
    )

    expect(appointment.reload).to be_canceled
    expect(appointment.deposit_status).to eq("failed")
    expect(appointment.cancellation_reason).to include("Mercado Pago")
    expect(payment.reload.status).to eq("rejected")
  end

  def create_business
    owner = User.create!(
      email_address: "mp-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )

    Business.create!(
      owner: owner,
      name: "MP Test Center",
      slug: "mp-test-center-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current,
      preferences: { "deposits_enabled" => true }
    )
  end

  def create_service(business)
    business.services.create!(
      name: "Esmaltado",
      category: "Uñas",
      duration_minutes: 30,
      price_cents: 20_000_00,
      active: true,
      public_visible: true,
      visibility_mode: "public",
      deposit_required: true,
      deposit_amount_cents: 5_000_00
    )
  end

  def create_pending_payment_appointment(business:, service:, starts_at:, deposit_amount_cents:)
    business.appointments.create!(
      service: service,
      customer_name: "Valentina",
      customer_phone: "+54 9 11 2222-2222",
      customer_email: "valentina-#{SecureRandom.hex(4)}@example.com",
      starts_at: starts_at,
      ends_at: starts_at + service.duration_minutes.minutes,
      status: :pending_payment,
      deposit_status: "pending",
      deposit_amount_cents: deposit_amount_cents,
      payment_collection_method: "mercado_pago",
      payment_charge_mode: "deposit",
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )
  end
end
