require "rails_helper"
require Rails.root.join("db/migrate/20261019130000_normalize_subscription_grace_period")

RSpec.describe NormalizeSubscriptionGracePeriod do
  it "preserves grace dates that contain a historical seven-day manual extension" do
    owner = User.create!(email_address: "migration-grace-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    business = Business.create!(owner: owner, name: "Migration Grace", slug: "migration-grace-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-1234", onboarding_completed_at: Time.current)
    subscription = business.subscription
    subscription.update_columns(
      next_due_on: Time.zone.today,
      grace_ends_on: Time.zone.today + 22.days
    )

    ActiveRecord::Migration.suppress_messages { described_class.new.up }

    expect(subscription.reload.grace_ends_on).to eq(Time.zone.today + 22.days)
  end
end
