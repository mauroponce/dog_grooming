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

  it "installs nine independently editable services without duplicates" do
    2.times { Grooming::Catalog.install!(business) }
    expect(business.services.count).to eq(9)
    expect(business.service_categories.count).to eq(3)
    expect(business.services.order(:price_cents).pluck(:price_cents)).to eq([ 15_000, 18_000, 20_000, 23_000, 25_000, 25_000, 28_000, 32_000, 40_000 ].map { |n| n * 100 })
    expect(business.services.find_by!(name: "Baño + corte grande").duration_minutes).to eq(135)
    expect(business.services.all?(&:deposit_required?)).to eq(true)
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

  it "limits active WhatsApp categories to nine" do
    9.times { |i| ServiceCategory.find_or_create_for!(business: business, name: "Categoría #{i}") }
    expect { ServiceCategory.find_or_create_for!(business: business, name: "Décima") }.to raise_error(ActiveRecord::RecordInvalid, /nueve/)
  end
end
