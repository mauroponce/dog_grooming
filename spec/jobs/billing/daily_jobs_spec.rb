require "rails_helper"
require "fugit"
require "yaml"

RSpec.describe "Billing recurring jobs" do
  it "runs lifecycle processing every fifteen minutes" do
    schedule = recurring_config.fetch("billing_daily_processor")

    expect(schedule).to include("class" => "Billing::DailyJob", "schedule" => "every 15 minutes")
    expect(Fugit.parse(schedule.fetch("schedule"))).to be_a(Fugit::Cron)
  end

  it "runs billing notifications at 8:30 in Argentina even when the server uses UTC" do
    schedule = recurring_config.fetch("billing_daily_notifications")
    cron = Fugit.parse(schedule.fetch("schedule"))

    expect(schedule.fetch("class")).to eq("Billing::DailyNotificationsJob")
    expect(cron).to be_a(Fugit::Cron)
    expect(cron.next_time(Time.utc(2026, 10, 19, 0)).utc).to eq(Time.utc(2026, 10, 19, 11, 30))
  end

  it "processes lifecycle state before creating daily notifications" do
    allow(Billing::DailyProcessor).to receive(:call)
    allow(Billing::DailyNotifications).to receive(:call)

    Billing::DailyNotificationsJob.perform_now

    expect(Billing::DailyProcessor).to have_received(:call).ordered
    expect(Billing::DailyNotifications).to have_received(:call).ordered
  end

  def recurring_config
    YAML.safe_load_file(Rails.root.join("config/recurring.yml")).fetch("production")
  end
end
