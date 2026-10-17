require "rails_helper"

RSpec.describe Appointments::CreateBooking do
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

  it "creates a manual-transfer deposit while simultaneous capacity is enabled" do
    business = create_business(
      simultaneous_capacity: 3,
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "manual_transfer" ]
      }
    )
    business.payment_accounts.create!(name: "Cuenta principal", details: "Alias: DEMO.SEÑAS", primary_account: true)
    starts_at = enable_availability_for(business)
    service = create_service(business, deposit_required: true, deposit_amount_cents: 5_000_00)

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Pérez",
      customer_phone: "+54 9 11 1111-1111",
      payment_method: "manual_transfer"
    )

    expect(appointment).to be_pending_deposit
    expect(appointment).to be_manual_payment_required
    expect(appointment.deposit_amount_cents).to eq(5_000_00)
    expect(appointment.payment_charge_mode).to eq("deposit")
  end

  it "keeps a manual-transfer booking under review when a receipt is attached" do
    business = create_business(
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "manual_transfer" ]
      }
    )
    business.payment_accounts.create!(name: "Cuenta principal", details: "Alias: DEMO.SEÑAS", primary_account: true)
    starts_at = enable_availability_for(business)
    service = create_service(business, deposit_required: true, deposit_amount_cents: 5_000_00)

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Pérez",
      customer_phone: "+54 9 11 1111-1111",
      payment_method: "manual_transfer",
      deposit_receipt: pdf_upload
    )

    expect(appointment).to be_pending_deposit_review
    expect(appointment.deposit_status).to eq("submitted")
    expect(appointment.deposit_receipt).to be_attached
  end

  it "rejects a deposit booking when the customer did not choose a payment method" do
    business = create_business(
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "manual_transfer" ]
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
        customer_phone: "+54 9 11 1111-1111"
      )
    end.to raise_error(ArgumentError, "Elegí un método de pago para reservar.")
  end

  it "rejects manual transfer when the business has no collection account" do
    business = create_business(
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "manual_transfer" ]
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
        customer_phone: "+54 9 11 1111-1111",
        payment_method: "manual_transfer"
      )
    end.to raise_error(ArgumentError, /no configuró una cuenta/)
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

  it "preserves grooming care for a returning pet and applies the selected size band" do
    business = create_business
    starts_at = enable_availability_for(business)
    service = create_service(business)
    service.update!(pricing_mode: "by_pet_size", deposit_percentage: 50)
    band = business.ensure_default_pet_size_bands!.second
    variant = service.service_variants.create!(pet_size_band: band, price_cents: 25_000_00, duration_minutes: 90)
    customer = business.customer_profiles.create!(name: "Ana", phone: "+54 11 6034-7665")
    pet = customer.pets.create!(name: "Coco", notes: "Cuidado especial", coat_type: "curly")

    appointment = described_class.call(
      business: business,
      service: service,
      service_variant: variant,
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
    expect(pet.pet_size_band).to eq(band)
  end

  it "rejects an inactive or foreign size variant" do
    business = create_business
    starts_at = enable_availability_for(business)
    service = create_service(business)
    service.update!(pricing_mode: "by_pet_size")
    band = business.ensure_default_pet_size_bands!.first
    variant = service.service_variants.create!(pet_size_band: band, price_cents: 20_000_00, duration_minutes: 60, active: false)

    expect do
      described_class.call(
        business: business,
        service: service,
        service_variant: variant,
        starts_at: starts_at,
        customer_name: "Julieta Pérez",
        customer_phone: "+54 9 11 1111-1111"
      )
    end.to raise_error(ArgumentError, /tamaño elegido no está disponible/)
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
