require "rails_helper"

RSpec.describe BillingReminder, type: :model do
  before(:context) do
    owner = User.create!(email_address: "billing-concurrency-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    @business = Business.create!(owner: owner, name: "Billing Concurrency", slug: "billing-concurrency-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-1234", onboarding_completed_at: Time.current)
    @invoice = @business.subscription.subscription_invoices.create!(
      business: @business,
      period_start: Time.zone.today,
      period_end: 1.month.from_now.to_date,
      billing_period_months: 1,
      amount_cents: @business.monthly_amount_cents,
      due_on: Time.zone.today,
      reference_code: "HT-CONCURRENT-#{SecureRandom.hex(4).upcase}",
      status: "open"
    )
  end

  after(:context) do
    @business.destroy!
  end

  it "allows only one reminder for the same event under concurrent creation" do
    attributes = {
      business_id: @business.id,
      subscription_invoice_id: @invoice.id,
      reminder_type: "due_today",
      channel: "email",
      recipient: @business.owner.email_address,
      event_on: @invoice.due_on,
      status: "pending"
    }
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          begin
            described_class.create!(attributes)
            results << :created
          rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
            results << :duplicate
          end
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)

    expect(2.times.map { results.pop }.sort).to eq(%i[created duplicate])
    expect(described_class.where(attributes.except(:status)).count).to eq(1)
  end

  it "allows the same reminder type after the invoice due date changes" do
    first = described_class.find_or_create_by!(
      business: @business,
      subscription_invoice: @invoice,
      reminder_type: "due_today",
      channel: "email",
      recipient: @business.owner.email_address,
      event_on: @invoice.due_on
    ) { |reminder| reminder.status = "pending" }
    new_due_on = @invoice.due_on + 7.days

    second = described_class.create!(
      business: @business,
      subscription_invoice: @invoice,
      reminder_type: "due_today",
      channel: "email",
      recipient: @business.owner.email_address,
      event_on: new_due_on,
      status: "pending"
    )

    expect(second.event_on).to eq(new_due_on)
    expect(second.id).not_to eq(first.id)
    expect(@invoice.billing_reminders.where(reminder_type: "due_today").count).to eq(2)
  end
end
