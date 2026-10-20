require "rails_helper"

RSpec.describe Appointments::CreateBooking do
  include ActiveJob::TestHelper

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it "confirms a public booking without deposit and leaves professional assignment internal" do
    business = create_business
    create_employee(business)
    starts_at = enable_availability_for(business)
    service = create_service(business)

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Pérez",
      customer_phone: "+54 9 11 1111-1111"
    )

    expect(appointment).to be_confirmed
    expect(appointment.deposit_status).to eq("not_required")
    expect(appointment.employee_membership).to be_nil
  end

  it "creates a Mercado Pago pending deposit while simultaneous capacity is enabled" do
    business = create_business(
      simultaneous_capacity: 3,
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "mercado_pago" ]
      }
    )
    allow(business).to receive(:mercado_pago_connected?).and_return(true)
    starts_at = enable_availability_for(business)
    service = create_service(business, deposit_required: true, deposit_amount_cents: 5_000_00)

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Pérez",
      customer_phone: "+54 9 11 1111-1111",
      payment_method: "mercado_pago"
    )

    expect(appointment).to be_mercado_pago_payment_pending
    expect(appointment.deposit_amount_cents).to eq(5_000_00)
    expect(appointment.payment_charge_mode).to eq("deposit")
    expiration_job = enqueued_jobs.find { |job| job.fetch(:job) == ExpirePendingDepositBookingsJob }
    expect(expiration_job.fetch(:args)).to eq([ appointment.id ])
  end

  it "rejects manual transfer even when collection details are present" do
    business = create_business(
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "mercado_pago" ]
      }
    )
    business.payment_accounts.create!(name: "Cuenta principal", details: "Alias: DEMO.SEÑAS", primary_account: true)
    starts_at = enable_availability_for(business)
    service = create_service(business, deposit_required: true, deposit_amount_cents: 5_000_00)

    expect do
      described_class.call(
        business: business,
        service: service,
        starts_at: starts_at,
        customer_name: "Julieta Pérez",
        customer_phone: "+54 9 11 1111-1111",
        payment_method: "manual_transfer",
        deposit_receipt: pdf_upload
      )
    end.to raise_error(ArgumentError, "Mercado Pago no está disponible para esta reserva.")
  end

  it "rejects a deposit booking while Mercado Pago is disconnected" do
    business = create_business(
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "mercado_pago" ]
      }
    )
    starts_at = enable_availability_for(business)
    service = create_service(business, deposit_required: true, deposit_amount_cents: 5_000_00)

    expect do
      described_class.call(
        business: business,
        service: service,
        starts_at: starts_at,
        customer_name: "Julieta Pérez",
        customer_phone: "+54 9 11 1111-1111"
      )
    end.to raise_error(ArgumentError, "Mercado Pago no está disponible para esta reserva.")
  end

  it "does not let a blocked customer reserve online" do
    business = create_business
    starts_at = enable_availability_for(business)
    service = create_service(business)
    customer = business.customer_profiles.create!(name: "Cliente Bloqueado", phone: "+54 9 11 1111-1111")
    customer.block!("Ausencias reiteradas")

    expect do
      described_class.call(
        business: business,
        service: service,
        starts_at: starts_at,
        customer_name: customer.name,
        customer_phone: customer.phone
      )
    end.to raise_error(Appointments::BlockedCustomer)
  end

  it "reuses a customer by normalized phone without overwriting canonical profile data" do
    business = create_business
    starts_at = enable_availability_for(business)
    service = create_service(business)
    customer = business.customer_profiles.create!(
      name: "Jennifer López",
      phone: "+54 9 11 1111-1111",
      email: "jennifer@example.test"
    )

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Jenny López",
      customer_phone: "+54 11 1111-1111",
      customer_email: "nuevo@example.test"
    )

    expect(appointment.customer_profile).to eq(customer)
    expect(customer.reload.name).to eq("Jennifer López")
    expect(customer.email).to eq("jennifer@example.test")
  end

  it "preserves grooming care for a returning pet" do
    business = create_business
    starts_at = enable_availability_for(business)
    service = create_service(business)
    customer = business.customer_profiles.create!(name: "Ana", phone: "+54 11 6034-7665")
    pet = customer.pets.create!(name: "Coco", notes: "Cuidado especial", coat_type: "curly")

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Ana",
      customer_phone: "1560347665",
      pet_name: " COCO ",
      pet_notes: "No sobrescribir",
      pet_coat_type: "short"
    )

    expect(appointment.pet).to eq(pet)
    expect(pet.reload.notes).to eq("Cuidado especial")
    expect(pet.coat_type).to eq("curly")
  end

  def create_business(preferences: {}, simultaneous_capacity: nil)
    owner = User.create!(email_address: "owner-#{SecureRandom.hex(4)}@example.test", role: :admin)
    Business.create!(
      owner: owner,
      name: "Peluquería Demo",
      slug: "peluqueria-demo-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 2222-2222",
      onboarding_completed_at: Time.current,
      simultaneous_capacity: simultaneous_capacity,
      preferences: preferences
    )
  end

  def create_service(business, deposit_required: false, deposit_amount_cents: 0)
    business.services.create!(
      name: "Baño completo",
      category: "Baño",
      duration_minutes: 60,
      price_cents: 20_000_00,
      deposit_required: deposit_required,
      deposit_amount_cents: deposit_amount_cents
    )
  end

  def create_employee(business)
    business.employee_memberships.create!(
      name: "Lucía Groomer",
      first_name: "Lucía",
      last_name: "Groomer",
      email_address: "equipo-#{SecureRandom.hex(4)}@example.test",
      status: "active"
    )
  end

  def enable_availability_for(business)
    date = 3.days.from_now.to_date
    starts_at = Time.zone.local(date.year, date.month, date.day, 10, 0)
    business.availability_rules.find_by!(weekday: date.wday).update!(active: true, start_time: "09:00", end_time: "18:00")
    starts_at
  end

  def pdf_upload
    file = Tempfile.new([ "comprobante", ".pdf" ])
    file.write("%PDF-1.4\ncomprobante")
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "application/pdf")
  end
end
