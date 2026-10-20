require "rails_helper"

RSpec.describe Business, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  it "creates a fourteen-day trial followed by three calendar grace days" do
    travel_to Time.zone.local(2026, 10, 1, 23, 30) do
      business = create_business

      expect(business.trial_ends_at).to eq(Time.zone.local(2026, 10, 15, 23, 30))
      expect(business.subscription).to have_attributes(
        status: "trialing",
        trial_ends_on: Date.new(2026, 10, 15),
        next_due_on: Date.new(2026, 10, 15),
        grace_ends_on: Date.new(2026, 10, 18)
      )
    end
  end

  it "keeps admin access and public bookings through the exact trial boundary and every grace day" do
    business = nil
    travel_to(Time.zone.local(2026, 10, 1, 10, 0)) { business = create_business }

    travel_to(Time.zone.local(2026, 10, 15, 9, 59)) do
      expect(business).to be_trial_active
      expect(business).to be_access_active
      expect(business).to be_booking_available
      expect(business.billing_status).to eq("trialing")
    end

    travel_to(Time.zone.local(2026, 10, 15, 10, 0)) do
      expect(business).not_to be_trial_active
      expect(business).to be_access_active
      expect(business.billing_status).to eq("payment_due")
    end

    (16..18).each do |day|
      travel_to Time.zone.local(2026, 10, day, 23, 59) do
        expect(business).to be_access_active
        expect(business).to be_booking_available
        expect(business.billing_status).to eq("overdue")
      end
    end

    travel_to Time.zone.local(2026, 10, 19, 0, 0) do
      expect(business).not_to be_access_active
      expect(business).not_to be_booking_available
      expect(business.billing_status).to eq("suspended")
    end
  end

  it "keeps access active while a payment is pending review after grace expires" do
    business = create_business
    business.subscription.update!(
      status: "pending_review",
      next_due_on: 10.days.ago.to_date,
      grace_ends_on: 7.days.ago.to_date
    )

    expect(business).to be_access_active
    expect(business).to be_booking_available
    expect(business.billing_status).to eq("pending_review")
  end

  private
    def create_business
      owner = User.create!(email_address: "lifecycle-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
      Business.create!(
        owner: owner,
        name: "Centro Lifecycle",
        slug: "centro-lifecycle-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-1234",
        onboarding_completed_at: Time.current
      )
    end
end
