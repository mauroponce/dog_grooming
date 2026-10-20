require "rails_helper"

RSpec.describe MercadoPago::ApproveBookingPayment do
  around do |example|
    previous = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous
  end
  let(:business) do
    owner = User.create!(email_address: "mp-late-#{SecureRandom.hex(4)}@example.com", password: "password123")
    owner.create_business!(name: "Pichipurris", slug: "mp-late-#{SecureRandom.hex(4)}", contact_phone: "5491111111111", simultaneous_capacity: 1)
  end
  let(:service) { business.services.create!(name: "Baño", category: "Baño", duration_minutes: 45, price_cents: 1_500_000) }
  let(:appointment) { business.appointments.create!(service: service, customer_name: "Julieta", customer_phone: "5491122222222", source: :public_booking, status: :pending_payment, starts_at: 3.days.from_now, payment_expires_at: 30.minutes.from_now, deposit_status: "pending", payment_collection_method: "mercado_pago", deposit_amount_cents: 750_000) }
  let(:payment) { AppointmentPayment.create!(business: business, appointment: appointment, amount_cents: 750_000) }
  let(:payload) { { "id" => "1234", "external_reference" => payment.external_reference, "status" => "approved", "transaction_amount" => 7_500, "currency_id" => "ARS" } }

  it "confirms and notifies only once across webhook and browser return" do
    allow(SendCustomerBookingConfirmationJob).to receive(:perform_later)
    2.times { described_class.call(payment: payment, payload: payload) }
    expect(appointment.reload).to be_confirmed
    expect(business.provider_events.where(event_type: "new_booking").count).to eq(1)
    expect(SendCustomerBookingConfirmationJob).to have_received(:perform_later).with(appointment).once
  end

  it "records a late payment without reclaiming an expired slot" do
    appointment.update!(payment_expires_at: 1.second.ago, status: :expired)
    described_class.call(payment: payment, payload: payload)
    expect(payment.reload).to be_approved
    expect(appointment.reload).to be_expired
    expect(business.provider_events.where(event_type: "late_payment").count).to eq(1)
  end

  it "rejects the wrong amount, currency or reference" do
    [ payload.merge("transaction_amount" => 100), payload.merge("currency_id" => "USD"), payload.merge("external_reference" => "other") ].each do |invalid|
      expect { described_class.call(payment: payment, payload: invalid) }.to raise_error(ArgumentError)
    end
    expect(payment.reload).not_to be_approved
  end

  it "expires pending Mercado Pago bookings and frees capacity" do
    appointment.update!(payment_expires_at: 1.second.ago)
    another_appointment = business.appointments.create!(
      service: service,
      customer_name: "Otra clienta",
      customer_phone: "5491133333333",
      source: :public_booking,
      status: :pending_payment,
      starts_at: 4.days.from_now,
      payment_expires_at: 1.second.ago,
      deposit_status: "pending",
      payment_collection_method: "mercado_pago",
      deposit_amount_cents: 750_000
    )

    ExpirePendingDepositBookingsJob.perform_now(appointment.id)

    expect(appointment.reload).to be_expired
    expect(another_appointment.reload).to be_pending_payment
    expect(Availability::SalonCapacity.available?(business: business, starts_at: appointment.starts_at, ends_at: appointment.ends_at)).to eq(true)
  end
end
