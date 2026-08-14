require "rails_helper"

RSpec.describe SendCustomerBookingConfirmationJob do
  it "sends the confirmed-booking email once and never contacts WhatsApp" do
    business, customer, appointment = create_confirmed_appointment
    customer_delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)

    expect(AppointmentMailer).to receive(:customer_booking_confirmed).with(appointment).and_return(customer_delivery)
    expect(WhatsApp::EvolutionClient).not_to receive(:new)

    described_class.perform_now(appointment)
    described_class.perform_now(appointment)

    expect(customer_delivery).to have_received(:deliver_later).once
    expect(appointment.notification_deliveries.where(template: "customer_booking_confirmed")).to contain_exactly(
      have_attributes(channel: "email", recipient: customer.email, status: "queued")
    )
    expect(business.notification_deliveries.where(channel: "whatsapp")).to be_empty
  end

  it "also notifies the business by email when Mercado Pago confirms the turn" do
    business, customer, appointment = create_confirmed_appointment(
      payment_collection_method: "mercado_pago",
      deposit_status: "approved",
      deposit_amount_cents: 5_000_00
    )
    customer_delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
    business_delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)

    allow(AppointmentMailer).to receive(:customer_booking_confirmed).with(appointment).and_return(customer_delivery)
    expect(BusinessMailer).to receive(:booking_confirmed_by_mercado_pago).with(appointment).and_return(business_delivery)

    described_class.perform_now(appointment)

    expect(customer_delivery).to have_received(:deliver_later)
    expect(business_delivery).to have_received(:deliver_later)
    expect(appointment.notification_deliveries.where(template: "mercado_pago_booking_confirmed")).to contain_exactly(
      have_attributes(channel: "email", recipient: business.owner.email_address, status: "queued")
    )
  end

  private
    def create_confirmed_appointment(payment_collection_method: "none", deposit_status: "not_required", deposit_amount_cents: 0)
      owner = User.create!(
        email_address: "confirmation-owner-#{SecureRandom.hex(4)}@example.com",
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
        visibility_mode: "public"
      )
      customer = business.customer_profiles.create!(
        name: "Valentina Gómez",
        phone: "+54 9 11 2222-2222",
        email: "valentina-#{SecureRandom.hex(4)}@example.com"
      )
      appointment = business.appointments.create!(
        service: service,
        customer_profile: customer,
        customer_name: customer.name,
        customer_phone: customer.phone,
        customer_email: customer.email,
        starts_at: Time.zone.local(2026, 8, 4, 11, 0, 0),
        ends_at: Time.zone.local(2026, 8, 4, 11, 30, 0),
        source: :public_booking,
        status: :confirmed,
        deposit_status: deposit_status,
        deposit_amount_cents: deposit_amount_cents,
        payment_collection_method: payment_collection_method,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )

      [ business, customer, appointment ]
    end
end
