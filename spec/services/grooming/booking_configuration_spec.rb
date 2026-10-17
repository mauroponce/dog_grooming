require "rails_helper"

RSpec.describe "Grooming booking configuration" do
  around do |example|
    previous = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous
  end

  let(:business) do
    owner = User.create!(email_address: "grooming-#{SecureRandom.hex(4)}@example.com", password: "password123")
    owner.create_business!(name: "Pichipurris", slug: "grooming-#{SecureRandom.hex(4)}", industry: "dog_grooming", contact_phone: "+5491111111111", onboarding_completed_at: Time.current, simultaneous_capacity: 3)
  end
  let(:date) { 3.days.from_now.to_date }
  let(:start) { Time.zone.local(date.year, date.month, date.day, 9) }
  let(:service) { business.services.create!(name: "Baño chico", category: "Baño", duration_minutes: 45, price_cents: 1_500_000) }

  def booking(at: start, **attrs)
    business.appointments.create!({ service: service, starts_at: at, source: :manual, status: :confirmed, customer_name: "Cliente", customer_phone: "+5491111111111" }.merge(attrs))
  end

  it "installs three services with shared weight ranges and editable variants without duplicates" do
    2.times { Grooming::Catalog.install!(business) }
    expect(business.services.count).to eq(3)
    expect(business.service_categories.count).to eq(3)
    expect(business.pet_size_bands.ordered.pluck(:name)).to eq([ "Chico", "Mediano", "Grande" ])
    expect(business.service_categories.order(:name).pluck(:name)).to eq([ "Baño + corte", "Baño y secado", "Sólo corte" ])
    expect(business.industry_details.fetch(:service_templates)).to eq(Grooming::Catalog.templates)
    expect(business.services.all?(&:tiered_pricing?)).to eq(true)
    expect(business.services.sum { |catalog_service| catalog_service.service_variants.count }).to eq(9)
    combined_service = business.services.find_by!(name: "Baño + corte")
    expect(combined_service.service_variants.ordered.pluck(:price_cents)).to eq([ 25_000, 32_000, 40_000 ].map { |n| n * 100 })
    expect(combined_service.service_variants.ordered.last.duration_minutes).to eq(135)
    expect(combined_service.deposit_amount_cents_for(4_000_000)).to eq(2_000_000)
    expect(business.services.all?(&:deposit_required?)).to eq(true)
  end

  it "uses the selected variant as an immutable appointment snapshot and remembers the pet range" do
    Grooming::Catalog.install!(business)
    catalog_service = business.services.find_by!(name: "Baño + corte")
    catalog_service.update!(deposit_required: false)
    variant = catalog_service.service_variants.ordered.last
    starts_at = 3.days.from_now.change(hour: 9, min: 0, sec: 0)
    business.availability_rules.find_by!(weekday: starts_at.wday).update!(active: true, start_time: "09:00", end_time: "13:00")

    appointment = Appointments::CreateBooking.call(
      business: business,
      service: catalog_service,
      service_variant: variant,
      starts_at: starts_at,
      customer_name: "Julieta Pérez",
      customer_phone: "+54 9 11 4444-4444",
      pet_name: "Coco",
      source: :manual
    )

    expect(appointment.ends_at).to eq(starts_at + 135.minutes)
    expect(appointment.base_price_cents).to eq(4_000_000)
    expect(appointment.service_variant_name).to eq("Grande · Más de 20 kg")
    expect(appointment.service_variant_price_cents).to eq(4_000_000)
    expect(appointment.pet.pet_size_band).to eq(variant.pet_size_band)

    variant.update!(price_cents: 5_000_000, duration_minutes: 150)
    expect(appointment.reload.service_variant_price_cents).to eq(4_000_000)
    expect(appointment.ends_at).to eq(starts_at + 135.minutes)
  end

  it "permits three simultaneous pets without assigning employees and rejects the fourth" do
    3.times { booking }
    expect { booking }.to raise_error(ActiveRecord::RecordInvalid, /cupo/)
    expect(business.appointments.count).to eq(3)
  end

  it "uses the peak occupancy rather than the count of all intersecting bookings" do
    business.update!(simultaneous_capacity: 2)
    booking(ends_at: start + 30.minutes)
    booking(at: start + 30.minutes, ends_at: start + 60.minutes)
    expect(Availability::SalonCapacity.available?(business: business, starts_at: start, ends_at: start + 60.minutes)).to eq(true)
    booking(at: start + 15.minutes)
    expect(Availability::SalonCapacity.available?(business: business, starts_at: start, ends_at: start + 60.minutes)).to eq(false)
  end

  it "releases capacity exactly at the end time and after cancellation" do
    business.update!(simultaneous_capacity: 1)
    first = booking
    expect(Availability::SalonCapacity.available?(business: business, starts_at: start + 45.minutes, ends_at: start + 90.minutes)).to eq(true)
    first.update!(status: :canceled)
    expect(Availability::SalonCapacity.available?(business: business, starts_at: start, ends_at: start + 45.minutes)).to eq(true)
  end

  it "offers independent continuous starts and exact per-day fixed starts" do
    business.availability_rules.find_by!(weekday: date.wday).update!(active: true, start_time: "09:00", end_time: "12:00")
    times = -> { Availability::Slots.public_for(business: business, service: service, date: date).map { |time| time.strftime("%H:%M") } }
    expect(times.call).to eq(%w[09:00 09:30 10:00 10:30 11:00])
    business.update!(arrival_mode: "fixed", arrival_times: { date.wday.to_s => %w[09:15 10:15 11:30] })
    expect(times.call).to eq(%w[09:15 10:15])
  end

  it "does not change the duration of appointments when the catalog is edited" do
    first = booking
    service.update!(duration_minutes: 135)
    first.update!(internal_notes: "Cuidados")
    expect(first.reload.ends_at).to eq(start + 45.minutes)
  end
end
