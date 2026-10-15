require "rails_helper"

RSpec.describe "WhatsApp automation" do
  around do |example|
    previous = ActiveJob::Base.queue_adapter
    previous_automation = ENV["WHATSAPP_AUTOMATION_ENABLED"]
    ENV["WHATSAPP_AUTOMATION_ENABLED"] = "true"
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous
    ENV["WHATSAPP_AUTOMATION_ENABLED"] = previous_automation
  end

  let(:business) do
    owner = User.create!(email_address: "wa-#{SecureRandom.hex(4)}@example.com", password: "password123")
    owner.create_business!(name: "Pichipurris", slug: "wa-#{SecureRandom.hex(4)}", industry: "dog_grooming", contact_phone: "+5491111111111", onboarding_completed_at: Time.current, simultaneous_capacity: 10)
  end
  let(:phone) { "5491122222222" }
  let(:contact) { business.whatsapp_contacts.create!(phone: phone, name: "Julieta", last_inbound_at: Time.current, opted_in_at: Time.current) }
  let(:service) { business.services.create!(name: "Baño chico", category: "Baño", duration_minutes: 45, price_cents: 1_500_000) }
  let(:appointment) { business.appointments.create!(service: service, customer_name: "Julieta", customer_phone: phone, customer_email: "julieta@example.com", source: :public_booking, status: :confirmed, starts_at: 2.days.from_now) }
  before { business.create_whatsapp_connection!(phone_number_id: "123", waba_id: "456", access_token: "secret", automation_enabled: true) }

  def event(kind: "inbound", **payload)
    business.whatsapp_events.create!(provider_id: SecureRandom.uuid, kind: kind, payload: { "from" => phone, "timestamp" => Time.current.to_i.to_s, "contact_name" => "Julieta" }.merge(payload.stringify_keys))
  end

  def connect_pro
    business.whatsapp_connection.update!(templates_approved: true)
    business.subscription.update!(plan_selected: "pro")
    contact
  end

  it "responds with a welcome list and deduplicates events" do
    Grooming::Catalog.install!(business)
    incoming = event(text: { "body" => "Hola" })
    2.times { WhatsApp::ProcessEventJob.perform_now(incoming.id) }
    expect(business.whatsapp_deliveries.count).to eq(1)
    payload = business.whatsapp_deliveries.first.payload
    expect(payload.dig("interactive", "body", "text")).to include("Bienvenido a Pichipurris")
    expect(payload.dig("interactive", "action", "sections", 0, "rows").length).to eq(10)
    expect(payload.dig("interactive", "action", "sections", 0, "rows", 0, "id")).to start_with("service:")
    expect(incoming.reload.payload).to eq({})
  end

  it "pauses only the requesting contact and renews on a human reply" do
    incoming = event(interactive: { "list_reply" => { "id" => "human" } })
    WhatsApp::ProcessEventJob.perform_now(incoming.id)
    expect(business.whatsapp_contacts.find_by!(phone: phone)).to be_paused
    WhatsApp::ProcessEventJob.perform_now(event(text: { "body" => "Hola otra vez" }).id)
    expect(business.whatsapp_deliveries.count).to eq(1)
    WhatsApp::ProcessEventJob.perform_now(event(from: "+5491133333333", text: { "body" => "Hola" }).id)
    expect(business.whatsapp_deliveries.count).to eq(2)
    WhatsApp::ProcessEventJob.perform_now(event(kind: "human", to: phone).id)
    expect(business.whatsapp_contacts.find_by!(phone: phone).last_human_at).to be_present
    business.whatsapp_contacts.find_by!(phone: phone).update!(paused_until: 1.second.ago, last_menu_at: 25.hours.ago)
    WhatsApp::ProcessEventJob.perform_now(event(text: { "body" => "Hola" }).id)
    expect(business.whatsapp_deliveries.count).to eq(3)
  end

  it "creates an expiring signed booking link without a phone query parameter" do
    WhatsApp::ProcessEventJob.perform_now(event(interactive: { "list_reply" => { "id" => "service:#{service.id}" } }).id)
    payload = business.whatsapp_deliveries.last.payload.dig("text", "body")
    expect(payload).to include("/r/")
    expect(payload).not_to include("phone=")
    expect(business.booking_intents.last.phone_e164).to eq(phone)
  end

  it "reserves only twenty trial reminders, keeps the booking operational and falls back to email" do
    connect_pro
    20.times do |i|
      booking = business.appointments.create!(service: service, customer_name: "Julieta", customer_phone: phone, starts_at: (i + 2).days.from_now, source: :public_booking, status: :confirmed)
      expect(WhatsApp::AppointmentNotifications.call(appointment: booking, purpose: "reminder")).to eq(true)
    end
    expect(WhatsApp::AppointmentNotifications.call(appointment: appointment, purpose: "reminder")).to eq(false)
    expect(business.whatsapp_deliveries.count).to eq(20)
    expect(business.provider_events.where(event_type: "whatsapp_trial_exhausted").count).to eq(1)
    expect(appointment.reload).to be_confirmed
    email = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    expect(AppointmentMailer).to receive(:customer_reminder).with(appointment).and_return(email)
    SendAppointmentReminderJob.perform_now(appointment)
    expect(appointment.reload.reminder_sent_at).to be_present
  end

  it "allows unlimited reminders after payment and never consumes trial quota for confirmations" do
    connect_pro
    business.subscription.update!(status: "active", paid_until: 1.month.from_now)
    expect(WhatsApp::AppointmentNotifications.call(appointment: appointment, purpose: "confirmation")).to eq(true)
    2.times { expect(WhatsApp::AppointmentNotifications.call(appointment: appointment, purpose: "reminder")).to eq(true) }
    expect(business.whatsapp_deliveries.count).to eq(2)
    expect(business.whatsapp_deliveries.where(trial_reminder: true)).to be_empty
  end

  it "does not send Basic confirmations outside the inbound window" do
    connect_pro
    business.subscription.update!(plan_selected: "basic")
    contact.update!(last_inbound_at: 25.hours.ago)
    expect(WhatsApp::AppointmentNotifications.call(appointment: appointment, purpose: "confirmation")).to eq(false)
    expect(business.whatsapp_deliveries).to be_empty
  end

  it "does not blindly resend when Meta times out" do
    connect_pro
    WhatsApp::AppointmentNotifications.call(appointment: appointment, purpose: "reminder")
    delivery = business.whatsapp_deliveries.last
    client = instance_double(WhatsApp::CloudClient)
    allow(WhatsApp::CloudClient).to receive(:new).and_return(client)
    expect(client).to receive(:send_message!).once.and_raise(WhatsApp::CloudClient::UncertainDelivery)
    2.times { WhatsApp::SendDeliveryJob.perform_now(delivery.id) }
    expect(delivery.reload.status).to eq("unknown")
  end

  it "keeps accepted trial usage when a booking is deleted" do
    connect_pro
    WhatsApp::AppointmentNotifications.call(appointment: appointment, purpose: "reminder")
    delivery = business.whatsapp_deliveries.last
    delivery.update!(status: "accepted", accepted_at: Time.current)
    appointment.destroy!
    expect(delivery.reload.appointment_id).to be_nil
    expect(business.whatsapp_deliveries.where(trial_reminder: true, status: "accepted").count).to eq(1)
  end

  it "does not send a reminder queued for an old appointment time" do
    connect_pro
    WhatsApp::AppointmentNotifications.call(appointment: appointment, purpose: "reminder")
    delivery = business.whatsapp_deliveries.last
    appointment.update!(starts_at: appointment.starts_at + 1.day, ends_at: appointment.ends_at + 1.day)
    expect(WhatsApp::CloudClient).not_to receive(:new)
    WhatsApp::SendDeliveryJob.perform_now(delivery.id)
    expect(delivery.reload.status).to eq("skipped")
  end

  it "paginates services with a human option on every page and never exceeds ten rows" do
    12.times { |index| business.services.create!(name: "Service #{index}", duration_minutes: 30, price_cents: 1000) }
    WhatsApp::ProcessEventJob.perform_now(event(text: { "body" => "Hola" }).id)
    rows = business.whatsapp_deliveries.last.payload.dig("interactive", "action", "sections", 0, "rows")
    expect(rows.length).to eq(10)
    expect(rows.map { |row| row["id"] }).to include("human", "services:1")
    WhatsApp::ProcessEventJob.perform_now(event(interactive: { "list_reply" => { "id" => "services:1" } }).id)
    next_rows = business.whatsapp_deliveries.last.payload.dig("interactive", "action", "sections", 0, "rows")
    expect(next_rows.length).to be <= 10
    expect(next_rows.map { |row| row["id"] }).to include("human", "services:0")
    first_ids = rows.filter_map { |row| row["id"] if row["id"].start_with?("service:") }
    next_ids = next_rows.filter_map { |row| row["id"] if row["id"].start_with?("service:") }
    expect(first_ids & next_ids).to be_empty
  end

  it "does not automatically repeat the menu on subsequent customer messages" do
    2.times { WhatsApp::ProcessEventJob.perform_now(event(text: { "body" => "Hola" }).id) }
    expect(business.whatsapp_deliveries.count).to eq(1)
  end

  it "keeps new connections silent even when the global switch is enabled" do
    business.whatsapp_connection.update!(automation_enabled: false)
    WhatsApp::ProcessEventJob.perform_now(event(text: { "body" => "Hola" }).id)
    expect(business.whatsapp_deliveries).to be_empty
  end

  it "does not answer an old event after the tenant connects a different number" do
    incoming = event(text: { "body" => "Hola" })
    incoming.update!(phone_number_id: "123")
    business.whatsapp_connection.update!(phone_number_id: "999")
    WhatsApp::ProcessEventJob.perform_now(incoming.id)
    expect(business.whatsapp_deliveries).to be_empty
    expect(business.whatsapp_contacts).to be_empty
  end

  it "does not open a service belonging to another tenant" do
    other = User.create!(email_address: "isolated-#{SecureRandom.hex(4)}@example.com", password: "password123").create_business!(name: "Other", slug: "isolated-#{SecureRandom.hex(4)}")
    other_service = other.services.create!(name: "Secret service", duration_minutes: 30, price_cents: 1000)
    WhatsApp::ProcessEventJob.perform_now(event(interactive: { "list_reply" => { "id" => "service:#{other_service.id}" } }).id)
    expect(business.booking_intents).to be_empty
    expect(business.whatsapp_deliveries.last.payload.to_json).not_to include("Secret service")
  end

  it "rejects templates on newly verified Coexistence connections" do
    business.whatsapp_connection.update!(verified_at: Time.current)
    delivery = WhatsAppDelivery.enqueue!(business: business, key: "no-templates", purpose: "reply", payload: { to: phone, type: "template" })
    expect(WhatsApp::CloudClient).not_to receive(:new)
    WhatsApp::SendDeliveryJob.perform_now(delivery.id)
    expect(delivery.reload.status).to eq("skipped")
  end

  it "never sends a queued reply outside the twenty-four-hour window" do
    contact.update!(last_inbound_at: 25.hours.ago)
    delivery = WhatsAppDelivery.enqueue!(business: business, key: "expired-window", purpose: "reply", payload: { to: phone, type: "text", text: { body: "Reply" } })
    expect(WhatsApp::CloudClient).not_to receive(:new)
    WhatsApp::SendDeliveryJob.perform_now(delivery.id)
    expect(delivery.reload.status).to eq("skipped")
  end

  it "does not reuse a previous connection's service window" do
    contact.update!(last_inbound_at: 1.minute.ago)
    business.whatsapp_connection.update!(connected_at: Time.current, verified_at: Time.current)
    expect(contact.reload).not_to be_window_open
    contact.update!(last_inbound_at: 1.second.from_now)
    expect(contact.reload).to be_window_open
  end

  it "keeps sent, delivered and read timestamps and billing data without downgrading out-of-order events" do
    delivery = WhatsAppDelivery.enqueue!(business: business, key: "status-history", purpose: "reply", payload: { to: phone })
    delivery.update!(provider_id: "wamid-outgoing", status: "accepted", accepted_at: Time.current)
    %w[read delivered sent].each do |status|
      incoming = business.whatsapp_events.create!(phone_number_id: "123", provider_id: "wamid-outgoing", kind: "status:#{status}", payload: { status: status, timestamp: Time.current.to_i.to_s, pricing: { billable: false, pricing_model: "PMP", category: "service" } })
      WhatsApp::ProcessEventJob.perform_now(incoming.id)
    end
    expect(delivery.reload.status).to eq("read")
    expect(delivery.delivered_at).to be_present
    expect(delivery.sent_at).to be_present
    expect(delivery.read_at).to be_present
    expect(delivery.billing_metadata.dig("pricing", "billable")).to be(false)
    expect(business.whatsapp_deliveries.monthly_usage.sole).to include(phone_number_id: "123", outgoing: 1, delivered: 1, read: 1, billable: 0)
  end
end
