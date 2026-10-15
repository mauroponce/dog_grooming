require "rails_helper"

RSpec.describe "WhatsApp booking", type: :request do
  around do |example|
    previous = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous
  end
  before { host! "localhost:3000" }
  let(:headers) { { "User-Agent" => "Mozilla/5.0 Chrome/130.0.0.0 Safari/537.36" } }
  let(:business) do
    owner = User.create!(email_address: "wa-web-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    owner.create_business!(name: "Pichipurris", slug: "wa-web-#{SecureRandom.hex(4)}", industry: "dog_grooming", contact_phone: "+5491111111111", onboarding_completed_at: Time.current, simultaneous_capacity: 3)
  end

  it "validates signed links, skips phone/name entry, accepts an optional email, and charges only the deposit" do
    Grooming::Catalog.install!(business)
    business.update!(preferences: business.preferences.merge("enabled_payment_methods" => [ "mercado_pago" ]))
    business.create_mercado_pago_connection!(access_token: "mp-test-token", connected_at: Time.current)
    service = business.services.find_by!(name: "Baño chico")
    starts_at = 3.days.from_now.change(hour: 10, min: 0, sec: 0)
    business.availability_rules.find_by!(weekday: starts_at.wday).update!(active: true, start_time: "09:00", end_time: "19:00")
    intent = business.booking_intents.create!(service: service, full_name: "Julieta", phone_e164: "+5491122222222", metadata: { source: "whatsapp" })
    get whatsapp_booking_path(token: "invalid"), headers: headers
    expect(response).to have_http_status(:not_found)
    get whatsapp_booking_path(token: intent.signed_id(expires_in: 2.hours, purpose: :whatsapp_booking)), headers: headers
    expect(response).to have_http_status(:redirect)
    get new_public_booking_path(business.slug, service_id: service.slug, step: "details", starts_at: starts_at.iso8601), headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('name="booking[customer_phone]"')
    expect(response.body).to include('name="booking[customer_email]"')
    post public_bookings_path(business.slug), params: { booking: { submission_step: "details", starts_at: starts_at.iso8601, pet_name: "Coco" } }, headers: headers
    expect(response).to have_http_status(:redirect)
    draft = Rack::Utils.parse_query(URI(response.location).query).fetch("draft")
    client = instance_double(MercadoPago::Client)
    allow(MercadoPago::Client).to receive(:for_connection).and_return(client)
    allow(client).to receive(:create_preference!).and_return("id" => "pref-123", "init_point" => "https://www.mercadopago.com.ar/checkout/v1/redirect?pref_id=pref-123")
    post public_bookings_path(business.slug), params: { booking: { submission_step: "mercado_pago", draft_token: draft } }, headers: headers
    expect(response.location).to include("mercadopago.com.ar")
    appointment = business.appointments.last
    expect(appointment.pet.name).to eq("Coco")
    expect(appointment.customer_phone).to eq("5491122222222")
    expect(appointment.deposit_amount_cents).to eq(750_000)
    expect(intent.reload).to be_completed
  end

  it "requires a valid Meta signature and durably deduplicates incoming webhook messages" do
    business.create_whatsapp_connection!(phone_number_id: "123", waba_id: "456", access_token: "secret")
    original = ENV["META_APP_SECRET"]
    ENV["META_APP_SECRET"] = "test-secret"
    payload = { object: "whatsapp_business_account", entry: [ { id: "456", changes: [ { field: "messages", value: { metadata: { phone_number_id: "123" }, messages: [ { id: "wamid-test", from: "5491122222222", timestamp: Time.current.to_i.to_s, text: { body: "Hola" } } ] } } ] } ] }.to_json
    post "/webhooks/whatsapp", params: payload, headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
    signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'test-secret', payload)}"
    2.times { post "/webhooks/whatsapp", params: payload, headers: { "CONTENT_TYPE" => "application/json", "X-Hub-Signature-256" => signature } }
    expect(response).to have_http_status(:ok)
    expect(business.whatsapp_events.count).to eq(1)
  ensure
    ENV["META_APP_SECRET"] = original
  end
end
