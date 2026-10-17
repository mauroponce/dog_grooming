require "rails_helper"

RSpec.describe Availability::Slots do
  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it "shows 30 minute services every 30 minutes by default" do
    business = create_business
    date = enable_availability_for(business, start_time: "09:00", end_time: "12:00").to_date
    service = create_service(business, duration_minutes: 30)

    slots = described_class.public_for(business: business, service: service, date: date)

    expect(time_labels(slots)).to include("09:00", "09:30", "10:00", "10:30", "11:00", "11:30")
    expect(time_labels(slots)).not_to include("09:15", "09:45", "10:15")
  end

  it "shows 15 minute services every 15 minutes by default" do
    business = create_business
    date = enable_availability_for(business, start_time: "09:00", end_time: "10:00").to_date
    service = create_service(business, duration_minutes: 15)

    slots = described_class.public_for(business: business, service: service, date: date)

    expect(time_labels(slots)).to include("09:00", "09:15", "09:30", "09:45")
  end

  it "shows 45 minute services every 45 minutes from the beginning of the available window" do
    business = create_business
    date = enable_availability_for(business, start_time: "09:00", end_time: "12:00").to_date
    service = create_service(business, duration_minutes: 45)

    slots = described_class.public_for(business: business, service: service, date: date)

    expect(time_labels(slots)).to eq([ "09:00", "09:45", "10:30", "11:15" ])
  end

  it "anchors public slots to the start of the available window" do
    business = create_business
    date = enable_availability_for(business, start_time: "10:00", end_time: "12:30").to_date
    service = create_service(business, duration_minutes: 45)

    slots = described_class.public_for(business: business, service: service, date: date)

    expect(time_labels(slots)).to eq([ "10:00", "10:45", "11:30" ])
  end

  it "uses the service duration even when an old custom public interval is present" do
    business = create_business
    date = enable_availability_for(business, start_time: "09:00", end_time: "10:00").to_date
    service = create_service(business, duration_minutes: 30, public_start_interval_minutes: 15)

    slots = described_class.public_for(business: business, service: service, date: date)

    expect(time_labels(slots)).to eq([ "09:00", "09:30" ])
  end

  it "does not show starts where the full service duration does not fit" do
    business = create_business
    date = enable_availability_for(business, start_time: "09:00", end_time: "09:45").to_date
    service = create_service(business, duration_minutes: 30)

    slots = described_class.public_for(business: business, service: service, date: date)

    expect(time_labels(slots)).to eq([ "09:00" ])
    expect(slots).not_to include(slot_on(date, "09:30"))
  end

  it "keeps visible slots backed by the full service duration" do
    business = create_business
    starts_at = enable_availability_for(business, start_time: "09:00", end_time: "10:00")
    service = create_service(business, duration_minutes: 30)

    appointment = Appointments::CreateBooking.call(
      business: business,
      service: service,
      starts_at: starts_at,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111"
    )

    expect(appointment.starts_at).to eq(starts_at)
    expect(appointment.ends_at).to eq(starts_at + 30.minutes)
  end

  it "rejects public bookings for internally valid but publicly hidden starts" do
    business = create_business
    starts_at = enable_availability_for(business, start_time: "09:00", end_time: "10:00") + 15.minutes
    service = create_service(business, duration_minutes: 30)

    expect(described_class.available?(business: business, service: service, starts_at: starts_at)).to eq(true)
    expect(described_class.public_available?(business: business, service: service, starts_at: starts_at)).to eq(false)

    expect do
      Appointments::CreateBooking.call(
        business: business,
        service: service,
        starts_at: starts_at,
        customer_name: "Julieta Perez",
        customer_phone: "+54 9 11 1111-1111"
      )
    end.to raise_error(Appointments::UnavailableSlot, "El turno ya no está disponible")
  end

  it "does not show slots outside a service date availability range" do
    business = create_business
    date = enable_availability_for(business, start_time: "09:00", end_time: "12:00").to_date
    service = create_service(business, duration_minutes: 30)
    service.update!(
      limit_availability_by_date: true,
      availability_starts_on: date + 1.day,
      availability_ends_on: date + 1.week
    )

    slots = described_class.public_for(business: business, service: service, date: date)

    expect(slots).to be_empty
  end

  it "uses business capacity instead of professional calendars for unassigned public slots" do
    business = create_business
    starts_at = enable_availability_for(business, start_time: "09:00", end_time: "12:00")
    allowed = create_employee(business, "Sofia")
    other = create_employee(business, "Camila")
    service = create_service(business, duration_minutes: 30)
    service.employee_memberships << allowed

    allowed.employee_availability_rules.find_by!(weekday: starts_at.wday).update!(
      active: true,
      start_time: "10:00",
      end_time: "11:00",
      inherits_business_hours: false
    )
    other.employee_availability_rules.find_by!(weekday: starts_at.wday).update!(
      active: true,
      start_time: "09:00",
      end_time: "12:00",
      inherits_business_hours: false
    )

    slots = described_class.public_for(business: business, service: service, date: starts_at.to_date)

    expect(time_labels(slots)).to eq([ "09:00", "09:30", "10:00", "10:30", "11:00", "11:30" ])
  end

  it "excludes recurring unavailable time blocks for the selected professional" do
    business = create_business
    starts_at = enable_availability_for(business, start_time: "09:00", end_time: "12:00")
    sofia = create_employee(business, "Sofia")
    service = create_service(business, duration_minutes: 30)
    service.employee_memberships << sofia

    business.availability_blocks.create!(
      employee_membership: sofia,
      starts_at: starts_at.change(hour: 10, min: 0),
      ends_at: starts_at.change(hour: 10, min: 30),
      block_type: "professional_block",
      reason: "No disponible",
      recurrence: "weekly"
    )

    slots = described_class.public_for(
      business: business,
      service: service,
      date: starts_at.to_date + 1.week,
      employee_membership: sofia
    )

    expect(time_labels(slots)).to include("09:30", "10:30")
    expect(time_labels(slots)).not_to include("10:00")
  end

  it "allows public booking during a block only when online booking is explicitly allowed" do
    business = create_business
    starts_at = enable_availability_for(business, start_time: "09:00", end_time: "12:00")
    sofia = create_employee(business, "Sofia")
    service = create_service(business, duration_minutes: 30)
    service.employee_memberships << sofia

    business.availability_blocks.create!(
      employee_membership: sofia,
      starts_at: starts_at.change(hour: 10, min: 0),
      ends_at: starts_at.change(hour: 10, min: 30),
      block_type: "professional_block",
      reason: "No disponible",
      online_booking_allowed: true
    )

    blocked_start = starts_at.change(hour: 10, min: 0)

    expect(described_class.public_available?(business: business, service: service, starts_at: blocked_start, employee_membership: sofia)).to eq(true)
    expect(described_class.available?(business: business, service: service, starts_at: blocked_start, employee_membership: sofia)).to eq(false)
  end

  it "assigns any-professional bookings to a professional without an unavailable time block" do
    business = create_business
    starts_at = enable_availability_for(business, start_time: "09:00", end_time: "12:00")
    sofia = create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    service = create_service(business, duration_minutes: 30)

    business.availability_blocks.create!(
      employee_membership: sofia,
      starts_at: starts_at.change(hour: 10, min: 0),
      ends_at: starts_at.change(hour: 10, min: 30),
      block_type: "professional_block",
      reason: "No disponible"
    )

    assigned = Bookings::AssignProfessionalService.call(
      business: business,
      service: service,
      starts_at: starts_at.change(hour: 10, min: 0),
      lock: false
    )

    expect(assigned).to eq(camila)
  end

  it "respects required resources when building public slots" do
    business = create_business
    starts_at = enable_availability_for(business, start_time: "09:00", end_time: "10:00")
    resource = business.bookable_resources.create!(name: "Cabina facial")
    sofia = create_employee(business, "Sofia")
    create_employee(business, "Camila")
    service = create_service(business, duration_minutes: 30)
    service.bookable_resources << resource

    business.appointments.create!(
      service: service,
      bookable_resource: resource,
      employee_membership: sofia,
      customer_name: "Reserva existente",
      customer_phone: "+54 9 11 9999-9999",
      starts_at: starts_at,
      status: :confirmed,
      source: :manual,
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )

    slots = described_class.public_for(business: business, service: service, date: starts_at.to_date)

    expect(time_labels(slots)).not_to include("09:00")
    expect(time_labels(slots)).to include("09:30")
  end

  it "prevents public reservations on every date in a business non-working period" do
    business = create_business
    starts_at = enable_availability_for(business, start_time: "09:00", end_time: "12:00")
    employee = create_employee(business, "Sofia")
    service = create_service(business, duration_minutes: 30)
    service.employee_memberships << employee
    blocked_dates = [ starts_at.to_date, starts_at.to_date + 1.day, starts_at.to_date + 2.days ]
    blocked_dates.each do |date|
      business.availability_rules.find_by!(weekday: date.wday).update!(active: true, start_time: "09:00", end_time: "12:00")
    end
    business.availability_blocks.create!(
      starts_at: starts_at.to_date.beginning_of_day,
      ends_at: (starts_at.to_date + 3.days).beginning_of_day,
      block_type: "non_working_period",
      reason: "Fecha no laborable",
      online_booking_allowed: false
    )

    blocked_dates.each do |date|
      expect(described_class.public_for(business: business, service: service, date: date)).to be_empty
    end

    expect {
      Appointments::CreateBooking.call(
        business: business,
        service: service,
        starts_at: slot_on(blocked_dates.second, "09:00"),
        customer_name: "Julieta Perez",
        customer_phone: "+54 9 11 1111-1111"
      )
    }.to raise_error(Appointments::UnavailableSlot, "El turno ya no está disponible")
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

  def create_service(business, duration_minutes:, public_start_interval_minutes: nil)
    business.services.create!(
      name: "Limpieza facial",
      category: "Facial",
      description: "Tratamiento facial completo.",
      duration_minutes: duration_minutes,
      public_start_interval_minutes: public_start_interval_minutes,
      price_cents: 20_000_00
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

  def enable_availability_for(business, start_time:, end_time:)
    date = 3.days.from_now.to_date
    business.availability_rules.find_by!(weekday: date.wday).update!(
      active: true,
      start_time: start_time,
      end_time: end_time
    )
    slot_on(date, start_time)
  end

  def slot_on(date, time)
    hour, minute = time.split(":").map(&:to_i)
    Time.zone.local(date.year, date.month, date.day, hour, minute)
  end

  def time_labels(slots)
    slots.map { |slot| slot.strftime("%H:%M") }
  end
end
