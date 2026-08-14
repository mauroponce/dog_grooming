require "rails_helper"

RSpec.describe DepositProofs::ApproveService do
  it "notifies the customer when an admin approves a submitted deposit" do
    owner = User.create!(
      email_address: "deposit-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )
    business = Business.create!(
      owner: owner,
      name: "Aura Estética",
      slug: "aura-estetica-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )
    service = business.services.create!(
      name: "Depilación",
      slug: "depilacion-#{SecureRandom.hex(4)}",
      duration_minutes: 30,
      price_cents: 12_000_00,
      active: true,
      public_visible: true,
      visibility_mode: "public",
      deposit_required: true,
      deposit_amount_cents: 3_000_00
    )
    customer = business.customer_profiles.create!(name: "Valentina Gómez", phone: "+54 9 11 2222-2222")
    appointment = business.appointments.create!(
      service: service,
      customer_profile: customer,
      customer_name: customer.name,
      customer_phone: customer.phone,
      starts_at: 2.days.from_now.change(hour: 11, min: 0, sec: 0),
      ends_at: 2.days.from_now.change(hour: 11, min: 30, sec: 0),
      source: :public_booking,
      status: :pending_deposit_review,
      deposit_status: "submitted",
      payment_collection_method: "manual_proof",
      payment_charge_mode: "deposit",
      deposit_amount_cents: 3_000_00,
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )

    expect(SendCustomerBookingConfirmationJob).to receive(:perform_later).with(appointment)

    described_class.new(appointment: appointment, actor: owner).call

    expect(appointment.reload).to be_confirmed
    expect(appointment.deposit_status).to eq("approved")
    event = business.provider_events.find_by!(event_type: "new_booking")
    expect(event.title).to eq("Nuevo turno confirmado")
    expect(event.metadata.fetch("appointment_id")).to eq(appointment.id)
  end
end
