require "rails_helper"

RSpec.describe "Concurrent salon reservations", type: :model do
  self.use_transactional_tests = false

  it "serializes competing writers for the last cup at the database boundary" do
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    owner = User.create!(email_address: "concurrency-#{SecureRandom.hex(6)}@example.com", password: "password123")
    business = owner.create_business!(name: "Concurrency", slug: "concurrency-#{SecureRandom.hex(5)}", simultaneous_capacity: 1, contact_phone: "5491111111111")
    service = business.services.create!(name: "Baño", category: "Baño", duration_minutes: 45, price_cents: 1_500_000)
    starts_at = 3.days.from_now.change(hour: 10, min: 0)
    ready, go, outcomes = Queue.new, Queue.new, Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          Appointment.create!(business_id: business.id, service_id: service.id, source: :manual, status: :confirmed, customer_name: "Concurrente", starts_at: starts_at)
          outcomes << :reserved
        rescue ActiveRecord::RecordInvalid
          outcomes << :unavailable
        end
      end
    end
    2.times { ready.pop }
    2.times { go << true }
    threads.each(&:value)
    expect(2.times.map { outcomes.pop }).to match_array(%i[reserved unavailable])
    expect(business.appointments.count).to eq(1)
  ensure
    threads&.each(&:join)
    business&.reload&.destroy!
    owner&.destroy!
    ActiveJob::Base.queue_adapter = adapter
  end
end
