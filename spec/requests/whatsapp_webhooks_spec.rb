require "rails_helper"

RSpec.describe "WhatsApp webhooks", type: :request do
  include ActiveJob::TestHelper

  around do |example|
    keys = %w[WHATSAPP_WEBHOOK_VERIFY_TOKEN WHATSAPP_AUTOMATION_ENABLED META_APP_SECRET]
    previous = ENV.to_h.slice(*keys)
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ENV["WHATSAPP_WEBHOOK_VERIFY_TOKEN"] = "webhook-test-token"
    ENV["META_APP_SECRET"] = "webhook-test-secret"
    ENV.delete("WHATSAPP_AUTOMATION_ENABLED")
    example.run
  ensure
    keys.each { |key| previous.key?(key) ? ENV[key] = previous[key] : ENV.delete(key) }
    ActiveJob::Base.queue_adapter = adapter
  end

  before { host! "localhost" }

  let(:business) do
    owner = User.create!(email_address: "webhook-#{SecureRandom.hex(4)}@example.com", password: "password123")
    owner.create_business!(name: "Webhook salon", slug: "webhook-#{SecureRandom.hex(4)}", industry: "dog_grooming")
  end
  let!(:connection) { business.create_whatsapp_connection!(phone_number_id: "123", waba_id: "456", access_token: "test-only") }
  let(:message) { { id: "wamid-incoming", from: "5491122222222", timestamp: Time.current.to_i.to_s, text: { body: "Hola privado" } } }
  let(:payload) do
    { object: "whatsapp_business_account", entry: [ { id: "456", changes: [ { field: "messages", value: { metadata: { phone_number_id: "123" }, messages: [ message ] } } ] } ] }
  end

  def deliver(body = payload.to_json, signature: nil)
    signature ||= "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', ENV.fetch('META_APP_SECRET'), body)}"
    post "/webhooks/whatsapp", params: body, headers: { "CONTENT_TYPE" => "application/json", "X-Hub-Signature-256" => signature }
  end

  it "returns the exact plaintext challenge over forwarded HTTPS" do
    get "/webhooks/whatsapp", params: { "hub.mode" => "subscribe", "hub.verify_token" => "webhook-test-token", "hub.challenge" => "00123456789" }, headers: { "X-Forwarded-Proto" => "https" }
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/plain")
    expect(response.body).to eq("00123456789")
  end

  it "rejects invalid tokens, modes and missing configuration" do
    [ [ "subscribe", "wrong" ], [ "wrong", "webhook-test-token" ], [ "subscribe", "" ] ].each do |mode, token|
      get "/webhooks/whatsapp", params: { "hub.mode" => mode, "hub.verify_token" => token, "hub.challenge" => "123" }
      expect(response).to have_http_status(:forbidden)
    end
    ENV.delete("WHATSAPP_WEBHOOK_VERIFY_TOKEN")
    get "/webhooks/whatsapp", params: { "hub.mode" => "subscribe", "hub.verify_token" => "", "hub.challenge" => "123" }
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects missing, incorrect, and modified-body signatures without persisting anything" do
    [ "", "sha256=invalid", "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', ENV.fetch('META_APP_SECRET'), payload.to_json + ' ')}" ].each do |signature|
      expect { deliver(signature: signature) }.not_to change(WhatsAppEvent, :count)
      expect(response).to have_http_status(:unauthorized)
    end
    ENV.delete("META_APP_SECRET")
    deliver(signature: "sha256=invalid")
    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts signed requests without a CSRF token and queues processing, not sending" do
    previous_csrf = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    expect(WhatsApp::CloudClient).not_to receive(:new)
    expect { deliver }.to have_enqueued_job(WhatsApp::ProcessEventJob)
    expect(response).to have_http_status(:ok)
    incoming = business.whatsapp_events.sole
    2.times { WhatsApp::ProcessEventJob.perform_now(incoming.id) }
    expect(incoming.reload.processed_at).to be_present
    expect(incoming.payload).to eq({})
    expect(business.whatsapp_contacts.sole.last_inbound_at).to be_present
    expect(business.whatsapp_deliveries).to be_empty
  ensure
    ActionController::Base.allow_forgery_protection = previous_csrf
  end

  it "deduplicates retries while requeuing a still-pending event" do
    2.times { deliver }
    expect(business.whatsapp_events.count).to eq(1)
    expect(enqueued_jobs.count { |job| job[:job] == WhatsApp::ProcessEventJob }).to eq(2)
    WhatsApp::ProcessEventJob.perform_now(business.whatsapp_events.sole.id)
    clear_enqueued_jobs
    deliver
    expect(enqueued_jobs).to be_empty
  end

  it "does not route an unknown, mismatched or disconnected number to a tenant" do
    value = payload[:entry][0][:changes][0][:value]
    value[:metadata][:phone_number_id] = "999"
    expect { deliver }.not_to change(WhatsAppEvent, :count)
    expect(response).to have_http_status(:ok)
    value[:metadata][:phone_number_id] = "123"
    payload[:entry][0][:id] = "999"
    expect { deliver }.not_to change(WhatsAppEvent, :count)
    payload[:entry][0][:id] = "456"
    connection.update!(disconnected_at: Time.current)
    expect { deliver }.not_to change(WhatsAppEvent, :count)
  end

  it "rejects signed malformed JSON or envelope structures" do
    [ "{", "[]", { object: "other", entry: [] }.to_json,
      { object: "whatsapp_business_account", entry: [ nil ] }.to_json ].each do |body|
      deliver(body)
      expect(response).to have_http_status(:bad_request)
    end
  end

  it "records delivery statuses and manual echoes without sending a reply" do
    change = payload[:entry][0][:changes][0]
    change[:value].delete(:messages)
    change[:value][:statuses] = [ { id: "wamid-outbound", status: "delivered", timestamp: Time.current.to_i.to_s } ]
    deliver
    expect(business.whatsapp_events.sole.kind).to eq("status:delivered")
    change[:field] = "smb_message_echoes"
    change[:value].delete(:statuses)
    change[:value][:message_echoes] = [ message.merge(to: "5491122222222") ]
    deliver
    human = business.whatsapp_events.find_by!(kind: "human")
    WhatsApp::ProcessEventJob.perform_now(human.id)
    expect(business.whatsapp_contacts.sole).to be_paused
    expect(business.whatsapp_deliveries).to be_empty
  end

  it "keeps pending deliveries unsent while automation is disabled" do
    delivery = business.whatsapp_deliveries.create!(dedupe_key: "phase-one", purpose: "reply", payload: { to: "5491122222222" })
    expect(WhatsApp::CloudClient).not_to receive(:new)
    WhatsApp::SendDeliveryJob.perform_now(delivery.id)
    expect(delivery.reload.status).to eq("pending")
  end

  it "filters webhook parameters and SQL payloads" do
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter("hub.verify_token" => "private", "entry" => payload[:entry])
    expect(filtered.values).to eq([ "[FILTERED]", "[FILTERED]" ])
    expect(WhatsAppEvent.filter_attributes).to include(:payload)
  end

  it "does not write message bodies or contact details into SQL logs" do
    output = StringIO.new
    previous_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(output)
    deliver
    WhatsApp::ProcessEventJob.perform_now(business.whatsapp_events.sole.id)
    expect(output.string).not_to include("Hola privado", "5491122222222")
  ensure
    ActiveRecord::Base.logger = previous_logger
  end
end
