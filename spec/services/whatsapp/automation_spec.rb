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

  def event(kind: "inbound", **payload)
    business.whatsapp_events.create!(provider_id: SecureRandom.uuid, kind: kind, payload: { "from" => phone, "timestamp" => Time.current.to_i.to_s, "contact_name" => "Julieta" }.merge(payload.stringify_keys))
  end

  def connect_pro
    business.create_whatsapp_connection!(phone_number_id: "123", waba_id: "456", access_token: "secret", templates_approved: true)
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
    expect(payload.dig("interactive", "action", "sections", 0, "rows").length).to eq(4)
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
end
