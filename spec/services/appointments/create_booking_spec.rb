require "rails_helper"

RSpec.describe Appointments::CreateBooking do
  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it "creates public bookings without deposit as confirmed" do
    business = create_business
    starts_at = enable_availability_for(business)
    service = create_service(business, price_cents: 20_000_00)

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111",
      customer_email: nil
    )

    expect(appointment).to be_confirmed
    expect(appointment.confirmed_at).to be_present
    expect(appointment.deposit_status).to eq("not_required")
    expect(appointment.customer_email).to be_blank
  end

  it "reuses an existing customer by normalized WhatsApp without overwriting their canonical name" do
    business = create_business
    starts_at = enable_availability_for(business)
    service = create_service(business, price_cents: 20_000_00)
    customer = business.customer_profiles.create!(
      name: "Jennifer López",
      phone: "+54 9 11 1111-1111",
      email: "jennifer@example.com"
    )

    expect do
      appointment = described_class.call(
        business: business,
        service: service,
        starts_at: starts_at,
        customer_name: "Jenny López",
        customer_phone: "+54 11 1111-1111",
        customer_email: "nuevo@example.com"
      )

      expect(appointment.customer_profile).to eq(customer)
      expect(appointment.customer_name).to eq("Jenny López")
    end.not_to change(CustomerProfile, :count)

    expect(customer.reload.name).to eq("Jennifer López")
    expect(customer.email).to eq("jennifer@example.com")
  end

  it "keeps deposit bookings under review when a receipt is attached" do
    business = create_business(
      preferences: {
        "deposits_enabled" => true,
        "deposit_percentage" => 50,
        "deposit_alias" => "estetica.demo"
      }
    )
    starts_at = enable_availability_for(business)
    service = create_service(business, price_cents: 48_000_00, deposit_required: true, deposit_amount_cents: 12_000_00)

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111",
      customer_email: "julieta@example.com",
      payment_method: "manual_transfer",
      deposit_receipt: pdf_upload
    )

    expect(appointment).to be_pending_deposit_review
    expect(appointment.deposit_status).to eq("submitted")
    expect(appointment.deposit_amount_cents).to eq(12_000_00)
    expect(appointment.deposit_receipt).to be_attached
  end

  it "creates manual-transfer deposit bookings as temporarily blocked until the receipt is uploaded" do
    business = create_business(
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "manual_transfer" ]
      }
    )
    business.payment_accounts.create!(name: "BBVA principal", details: "Alias: CASA.TONY", primary_account: true)
    starts_at = enable_availability_for(business)
    service = create_service(business, price_cents: 20_000_00, deposit_required: true, deposit_amount_cents: 5_000_00)

    expect(SendAppointmentReservedMessageJob).to receive(:perform_later) do |appointment|
      expect(appointment).to be_public_booking
      expect(appointment).to be_pending_deposit
    end

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111",
      payment_method: "manual_transfer"
    )

    expect(appointment).to be_pending_deposit
    expect(appointment).to be_manual_payment_required
    expect(appointment.deposit_status).to eq("pending")
    expect(appointment.deposit_amount_cents).to eq(5_000_00)
    expect(appointment.remaining_balance_cents).to eq(15_000_00)
    expect(appointment.payment_charge_mode).to eq("deposit")
  end

  it "creates Mercado Pago deposit bookings as payment-pending without charging the full service total" do
    business = create_business(
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "mercado_pago" ]
      }
    )
    business.create_mercado_pago_connection!(
      access_token: "mp-token",
      refresh_token: "mp-refresh",
      mercado_pago_user_id: "123",
      connected_at: Time.current
    )
    starts_at = enable_availability_for(business)
    service = create_service(business, price_cents: 20_000_00, deposit_required: true, deposit_amount_cents: 4_000_00)

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111",
      payment_method: "mercado_pago"
    )

    expect(appointment).to be_pending_payment
    expect(appointment).to be_mercado_pago_payment_required
    expect(appointment.deposit_amount_cents).to eq(4_000_00)
    expect(appointment.remaining_balance_cents).to eq(16_000_00)
    expect(appointment.payment_charge_mode).to eq("deposit")
  end

  it "caps the effective deposit to the service total and still treats it as a deposit" do
    business = create_business(
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "manual_transfer" ]
      }
    )
    business.payment_accounts.create!(name: "BBVA principal", details: "Alias: CASA.TONY", primary_account: true)
    starts_at = enable_availability_for(business)
    service = create_service(business, price_cents: 10_000_00, deposit_required: true, deposit_amount_cents: 15_000_00)

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111",
      payment_method: "manual_transfer"
    )

    expect(appointment.deposit_amount_cents).to eq(10_000_00)
    expect(appointment.remaining_balance_cents).to eq(0)
    expect(appointment.payment_charge_mode).to eq("deposit")
  end

  it "rejects public deposit bookings when no payment method is selected" do
    business = create_business(
      preferences: {
        "deposits_enabled" => true,
        "enabled_payment_methods" => [ "manual_transfer" ]
      }
    )
    business.payment_accounts.create!(name: "BBVA principal", details: "Alias: CASA.TONY", primary_account: true)
    starts_at = enable_availability_for(business)
    service = create_service(business, price_cents: 20_000_00, deposit_required: true, deposit_amount_cents: 5_000_00)

    expect do
      described_class.call(
        business: business,
        service: service,
        starts_at: starts_at,
        customer_name: "Julieta Perez",
        customer_phone: "+54 9 11 1111-1111"
      )
    end.to raise_error(ArgumentError, "Elegí un método de pago para reservar.")
  end

  it "rejects a professional that is not assigned to the service" do
    business = create_business
    starts_at = enable_availability_for(business)
    allowed = create_employee(business, "Sofia")
    other = create_employee(business, "Camila")
    service = create_service(business, price_cents: 20_000_00)
    service.employee_memberships << allowed

    expect do
      described_class.call(
        business: business,
        service: service,
        starts_at: starts_at,
        customer_name: "Julieta Perez",
        customer_phone: "+54 9 11 1111-1111",
        employee_membership: other
      )
    end.to raise_error(Appointments::UnavailableSlot, "Ese profesional no realiza este servicio")
  end

  it "rejects a professional outside their own schedule" do
    business = create_business
    starts_at = enable_availability_for(business)
    employee = create_employee(business, "Sofia")
    service = create_service(business, price_cents: 20_000_00)
    service.employee_memberships << employee
    employee.employee_availability_rules.find_by!(weekday: starts_at.wday).update!(
      active: false,
      start_time: "09:00",
      end_time: "18:00",
      inherits_business_hours: false
    )

    expect do
      described_class.call(
        business: business,
        service: service,
        starts_at: starts_at,
        customer_name: "Julieta Perez",
        customer_phone: "+54 9 11 1111-1111",
        employee_membership: employee
      )
    end.to raise_error(Appointments::UnavailableSlot, "El turno ya no está disponible")
  end

  it "uses the team pool only with professionals assigned to the service" do
    business = create_business
    starts_at = enable_availability_for(business)
    allowed = create_employee(business, "Sofia")
    other = create_employee(business, "Camila")
    service = create_service(business, price_cents: 20_000_00)
    service.employee_memberships << allowed
    allowed.employee_availability_rules.find_by!(weekday: starts_at.wday).update!(
      active: true,
      start_time: "10:00",
      end_time: "11:00",
      inherits_business_hours: false
    )
    other.employee_availability_rules.find_by!(weekday: starts_at.wday).update!(
      active: true,
      start_time: "12:00",
      end_time: "18:00",
      inherits_business_hours: false
    )

    slots = Availability::Slots.for(business: business, service: service, date: starts_at.to_date)

    expect(slots).to include(starts_at)
    expect(slots).not_to include(starts_at.change(hour: 12))
  end

  it "rejects a slot when the required resource is already booked" do
    business = create_business
    starts_at = enable_availability_for(business)
    resource = business.bookable_resources.create!(name: "Cabina facial")
    employee = create_employee(business, "Sofia")
    other_employee = create_employee(business, "Camila")
    service = create_service(business, price_cents: 20_000_00)
    service.bookable_resources << resource

    business.appointments.create!(
      service: service,
      bookable_resource: resource,
      employee_membership: other_employee,
      customer_name: "Reserva existente",
      customer_phone: "+54 9 11 9999-9999",
      starts_at: starts_at,
      status: :confirmed,
      source: :manual,
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )

    expect do
      described_class.call(
        business: business,
        service: service,
        starts_at: starts_at,
        customer_name: "Julieta Perez",
        customer_phone: "+54 9 11 1111-1111",
        employee_membership: employee
      )
    end.to raise_error(Appointments::UnavailableSlot, "El turno ya no está disponible")
  end

  it "allows simultaneous bookings when the required resource has enough capacity" do
    business = create_business
    starts_at = enable_availability_for(business)
    resource = business.bookable_resources.create!(name: "Camilla corporal", resource_type: "bed", quantity: 2)
    sofia = create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    service = create_service(business, price_cents: 20_000_00)
    service.bookable_resources << resource

    first = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111",
      employee_membership: sofia
    )

    second = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Martina Gomez",
      customer_phone: "+54 9 11 2222-2222",
      employee_membership: camila
    )

    expect(first.bookable_resource).to eq(resource)
    expect(second.bookable_resource).to eq(resource)
  end

  it "assigns a concrete professional when the customer picks any professional" do
    business = create_business
    starts_at = enable_availability_for(business)
    employee = create_employee(business, "Sofia")
    service = create_service(business, price_cents: 20_000_00)
    service.employee_memberships << employee

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111"
    )

    expect(appointment.employee_membership).to eq(employee)
  end

  it "assigns the first available professional by default for public bookings" do
    business = create_business
    starts_at = enable_availability_for(business)
    sofia = create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    service = create_service(business, price_cents: 20_000_00)
    sofia.update!(sort_order: 1)
    camila.update!(sort_order: 2)

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111"
    )

    expect(appointment.employee_membership).to eq(sofia)
  end

  it "uses first available when professional selection is enabled and the customer picks no preference" do
    business = create_business(
      preferences: {
        "public_booking_allow_professional_selection" => true,
        "public_booking_assignment_strategy" => "least_daily_load"
      }
    )
    starts_at = enable_availability_for(business)
    sofia = create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    service = create_service(business, price_cents: 20_000_00)
    sofia.update!(sort_order: 1)
    camila.update!(sort_order: 2)
    business.appointments.create!(
      service: service,
      employee_membership: sofia,
      customer_name: "Cliente del día",
      customer_phone: "+54 9 11 2222-2222",
      starts_at: starts_at + 1.hour,
      source: :manual,
      status: :confirmed
    )

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111"
    )

    expect(appointment.employee_membership).to eq(sofia)
  end

  it "assigns the professional with the lowest total load for balanced rotation" do
    business = create_business(
      preferences: {
        "public_booking_assignment_strategy" => "balanced_rotation"
      }
    )
    starts_at = enable_availability_for(business)
    sofia = create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    service = create_service(business, price_cents: 20_000_00)
    sofia.update!(sort_order: 1)
    camila.update!(sort_order: 2)
    business.appointments.create!(
      service: service,
      employee_membership: sofia,
      customer_name: "Cliente previo",
      customer_phone: "+54 9 11 2222-2222",
      starts_at: starts_at + 1.day,
      source: :manual,
      status: :confirmed
    )

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111"
    )

    expect(appointment.employee_membership).to eq(camila)
  end

  it "assigns the professional with the lowest daily load" do
    business = create_business(
      preferences: {
        "public_booking_assignment_strategy" => "least_daily_load"
      }
    )
    starts_at = enable_availability_for(business)
    sofia = create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    service = create_service(business, price_cents: 20_000_00)
    sofia.update!(sort_order: 1)
    camila.update!(sort_order: 2)
    business.appointments.create!(
      service: service,
      employee_membership: sofia,
      customer_name: "Cliente del día",
      customer_phone: "+54 9 11 2222-2222",
      starts_at: starts_at + 1.hour,
      source: :manual,
      status: :confirmed
    )

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111"
    )

    expect(appointment.employee_membership).to eq(camila)
  end

  it "prioritizes the customer's habitual professional when available" do
    business = create_business(
      preferences: {
        "public_booking_assignment_strategy" => "habitual_professional"
      }
    )
    starts_at = enable_availability_for(business)
    sofia = create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    service = create_service(business, price_cents: 20_000_00)
    sofia.update!(sort_order: 1)
    camila.update!(sort_order: 2)
    customer = business.customer_profiles.create!(
      name: "Julieta Perez",
      phone: "+54 9 11 1111-1111"
    )
    business.appointments.create!(
      service: service,
      customer_profile: customer,
      employee_membership: camila,
      customer_name: customer.name,
      customer_phone: customer.phone,
      starts_at: starts_at - 7.days,
      source: :manual,
      status: :confirmed
    )

    appointment = described_class.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111"
    )

    expect(appointment.employee_membership).to eq(camila)
  end

  it "excludes slots blocked by a center availability block" do
    business = create_business
    starts_at = enable_availability_for(business)
    employee = create_employee(business, "Sofia")
    service = create_service(business, price_cents: 20_000_00)
    service.employee_memberships << employee
    business.availability_blocks.create!(
      starts_at: starts_at - 15.minutes,
      ends_at: starts_at + 45.minutes,
      block_type: "center_block",
      reason: "Capacitación"
    )

    expect(Availability::Slots.for(business: business, service: service, date: starts_at.to_date)).not_to include(starts_at)
  end

  it "excludes slots on closed holidays" do
    business = create_business
    starts_at = enable_availability_for(business)
    employee = create_employee(business, "Sofia")
    service = create_service(business, price_cents: 20_000_00)
    service.employee_memberships << employee
    business.holidays.create!(date: starts_at.to_date, name: "Feriado nacional", closed: true)

    expect(Availability::Slots.for(business: business, service: service, date: starts_at.to_date)).to be_empty
  end

  it "applies optional advanced availability rules for a service" do
    business = create_business
    starts_at = enable_availability_for(business)
    employee = create_employee(business, "Sofia")
    service = create_service(business, price_cents: 20_000_00)
    service.employee_memberships << employee
    service.update!(use_advanced_availability: true)
    service.service_availability_rules.create!(
      weekday: starts_at.wday,
      start_time: "15:00",
      end_time: "18:00",
      active: true
    )

    slots = Availability::Slots.for(business: business, service: service, date: starts_at.to_date)

    expect(slots).not_to include(starts_at)
    expect(slots).to include(starts_at.change(hour: 15))
  end

  it "rejects a slot when the required resource is manually blocked" do
    business = create_business
    starts_at = enable_availability_for(business)
    resource = business.bookable_resources.create!(name: "Laser Candela", resource_type: "machine")
    employee = create_employee(business, "Sofia")
    service = create_service(business, price_cents: 20_000_00)
    service.bookable_resources << resource
    business.resource_blocks.create!(
      bookable_resource: resource,
      starts_at: starts_at - 15.minutes,
      ends_at: starts_at + 45.minutes,
      reason: "maintenance"
    )

    expect(Availability::Slots.for(business: business, service: service, date: starts_at.to_date, employee_membership: employee)).not_to include(starts_at)
    expect do
      described_class.call(
        business: business,
        service: service,
        starts_at: starts_at,
        customer_name: "Julieta Perez",
        customer_phone: "+54 9 11 1111-1111",
        employee_membership: employee
      )
    end.to raise_error(Appointments::UnavailableSlot, "El turno ya no está disponible")
  end

  def create_business(preferences: {})
    owner = User.create!(
      email_address: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    Business.create!(
      owner: owner,
      name: "Estetica Demo",
      slug: "estetica-demo-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 2222-2222",
      onboarding_completed_at: Time.current,
      preferences: preferences
    )
  end

  def create_service(business, price_cents:, deposit_required: false, deposit_amount_cents: 0)
    business.services.create!(
      name: "Limpieza facial",
      category: "Facial",
      duration_minutes: 60,
      price_cents: price_cents,
      deposit_required: deposit_required,
      deposit_amount_cents: deposit_amount_cents
    )
  end

  def create_employee(business, name)
    first_name, last_name = employee_name_parts(name)
    business.employee_memberships.create!(
      name: name,
      first_name: first_name,
      last_name: last_name,
      email_address: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
      status: "active"
    )
  end

  def employee_name_parts(name)
    parts = name.to_s.split
    [ parts.first || "Profesional", parts.drop(1).join(" ").presence || "Test" ]
  end

  def enable_availability_for(business)
    date = 3.days.from_now.to_date
    starts_at = Time.zone.local(date.year, date.month, date.day, 10, 0)
    business.availability_rules.find_by!(weekday: date.wday).update!(
      active: true,
      start_time: "09:00",
      end_time: "18:00"
    )
    starts_at
  end

  def pdf_upload
    file = Tempfile.new([ "comprobante", ".pdf" ])
    file.write("%PDF-1.4\ncomprobante")
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "application/pdf")
  end
end
