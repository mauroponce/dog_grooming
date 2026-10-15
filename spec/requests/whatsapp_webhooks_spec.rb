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

  before do
    host! "localhost"
    clear_enqueued_jobs
    clear_performed_jobs
  end

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

  it "routes status events to the right tenant and preserves delivery/billing details" do
    outgoing = WhatsAppDelivery.enqueue!(business: business, key: "webhook-status", purpose: "reply", payload: { to: "5491122222222" })
    outgoing.update!(provider_id: "wamid-outbound", status: "accepted", accepted_at: Time.current)
    change = payload[:entry][0][:changes][0]
    change[:value].delete(:messages)
    change[:value][:statuses] = [ { id: "wamid-outbound", status: "delivered", timestamp: Time.current.to_i.to_s, pricing: { billable: false, category: "service", pricing_model: "PMP" } } ]
    deliver
    incoming = business.whatsapp_events.sole
    expect(incoming.phone_number_id).to eq("123")
    WhatsApp::ProcessEventJob.perform_now(incoming.id)
    expect(outgoing.reload.status).to eq("delivered")
    expect(outgoing.billing_metadata.dig("pricing", "billable")).to be(false)
  end

  it "acknowledges synchronization without importing historical messages into the bot" do
    connection.update!(connected_at: 1.minute.ago, verified_at: Time.current)
    change = payload[:entry][0][:changes][0]
    change[:field] = "history"
    change[:value].delete(:messages)
    change[:value][:history] = [ { threads: [ { messages: [ { text: { body: "Private historical content" } } ] } ] } ]
    deliver
    incoming = business.whatsapp_events.sole
    expect(incoming.kind).to eq("sync:history")
    expect(incoming.payload.to_json).not_to include("Private historical content")
    WhatsApp::ProcessEventJob.perform_now(incoming.id)
    expect(connection.reload.sync_metadata.dig("history", "received_at")).to be_present
    expect(business.whatsapp_contacts).to be_empty
    expect(business.whatsapp_deliveries).to be_empty
  end

  it "disconnects on a signed account removal but ignores a removal older than reconnection" do
    connection.update!(connected_at: 1.minute.ago)
    entry = payload[:entry][0]
    entry[:time] = 2.minutes.ago.to_i
    entry[:changes] = [ { field: "account_update", value: { event: "PARTNER_APP_UNINSTALLED", waba_info: { partner_app_id: ENV.fetch("META_APP_ID", "test-app") } } } ]
    previous_id = ENV["META_APP_ID"]
    ENV["META_APP_ID"] ||= "test-app"
    deliver
    WhatsApp::ProcessEventJob.perform_now(business.whatsapp_events.sole.id)
    expect(connection.reload).to be_connected
    entry[:time] = Time.current.to_i
    deliver
    WhatsApp::ProcessEventJob.perform_now(business.whatsapp_events.order(:id).last.id)
    expect(connection.reload).not_to be_connected
    expect(connection.access_token).to be_nil
  ensure
    ENV["META_APP_ID"] = previous_id
  end

  context "ACCOUNT_RECONNECTED auditing" do
    let(:account_payload) do
      { object: "whatsapp_business_account", entry: [ { id: "456", time: Time.current.to_i,
        changes: [ { field: "account_update", value: { event: "ACCOUNT_RECONNECTED" } } ] } ] }
    end

    it "audits a disconnected account without restoring credentials or changing any connection state" do
      connection.update!(disconnected_at: 1.day.ago, access_token_ciphertext: nil, authorization_failed_at: 1.day.ago, automation_enabled: false)
      previous = connection.reload.attributes
      expect(WhatsApp::CloudClient).not_to receive(:new)
      deliver(account_payload.to_json)
      expect(response).to have_http_status(:ok)
      event = business.whatsapp_events.sole
      expect(event.kind).to eq("account_reconnected")
      expect(event.phone_number_id).to eq("123")
      expect(event.provider_id).to be_present
      expect(event.payload).to include("event" => "ACCOUNT_RECONNECTED", "timestamp" => account_payload[:entry][0][:time].to_s, "waba_id" => "456")
      2.times { WhatsApp::ProcessEventJob.perform_now(event.id) }
      expect(event.reload.processed_at).to be_present
      expect(event.payload["event"]).to eq("ACCOUNT_RECONNECTED")
      expect(connection.reload.attributes).to eq(previous)
      expect(connection).not_to be_connected
      expect(business.whatsapp_deliveries).to be_empty
      expect(WhatsApp.automation_enabled?(business)).to be_falsey
    end

    it "deduplicates reconnect deliveries and does not enqueue an already processed audit again" do
      connection.update!(automation_enabled: false)
      2.times { deliver(account_payload.to_json) }
      expect(business.whatsapp_events.count).to eq(1)
      event = business.whatsapp_events.sole
      expect(event.kind).to eq("account_reconnected")
      WhatsApp::ProcessEventJob.perform_now(event.id)
      clear_enqueued_jobs
      deliver(account_payload.to_json)
      expect(business.whatsapp_events.count).to eq(1)
      expect(enqueued_jobs).to be_empty
      expect(connection.reload.automation_enabled).to be(false)
    end

    it "logs an unmapped reconnect safely without assigning another tenant or queuing a job" do
      account_payload[:entry][0][:id] = "999"
      account_payload[:entry][0][:changes][0][:value].merge!(metadata: { phone_number_id: "123" }, text: { body: "PRIVATE_UNMAPPED_BODY" })
      captured = []
      allow(Rails.logger).to receive(:warn) { |line| captured << line }
      queued_before = enqueued_jobs.dup
      2.times do
        expect { deliver(account_payload.to_json) }.not_to change(WhatsAppEvent, :count)
        expect(response).to have_http_status(:ok)
      end
      diagnostics = captured.map { |line| JSON.parse(line) }
      expect(diagnostics.length).to eq(2)
      expect(diagnostics.map { |event| event.fetch("event_id") }.uniq.length).to eq(1)
      expect(diagnostics.first).to include("event" => "whatsapp_account_reconnected_unmapped", "reason" => "unknown_connection", "waba_id" => "999", "phone_number_id" => "123")
      expect(captured.join).not_to include("PRIVATE_UNMAPPED_BODY")
      expect(diagnostics.first).not_to have_key("business_id")
      expect(enqueued_jobs).to eq(queued_before)
    end

    it "does not guess a tenant when multiple connections share the WABA" do
      other = User.create!(email_address: "wa-audit-other-#{SecureRandom.hex(4)}@example.com", password: "password123")
        .create_business!(name: "Other salon", slug: "wa-audit-other-#{SecureRandom.hex(4)}")
      other_connection = other.create_whatsapp_connection!(phone_number_id: "789", waba_id: "456", access_token: "other-test-token", disconnected_at: Time.current, automation_enabled: false)
      allow(Rails.logger).to receive(:warn)
      expect { deliver(account_payload.to_json) }.not_to change(WhatsAppEvent, :count)
      expect(Rails.logger).to have_received(:warn).with(a_string_including('"reason":"ambiguous_connection"'))
      account_payload[:entry][0][:changes][0][:value][:metadata] = { phone_number_id: "789" }
      deliver(account_payload.to_json)
      expect(business.whatsapp_events).to be_empty
      event = other.whatsapp_events.sole
      expect(event.phone_number_id).to eq("789")
      expect(event.kind).to eq("account_reconnected")
      snapshot = other_connection.reload.attributes
      WhatsApp::ProcessEventJob.perform_now(event.id)
      expect(other_connection.reload.attributes).to eq(snapshot)
      expect(other.whatsapp_deliveries).to be_empty
    end

    it "does not fall back to another number if an explicit phone ID does not match" do
      account_payload[:entry][0][:changes][0][:value][:metadata] = { phone_number_id: "999" }
      allow(Rails.logger).to receive(:warn)
      expect { deliver(account_payload.to_json) }.not_to change(WhatsAppEvent, :count)
      expect(Rails.logger).to have_received(:warn).with(a_string_including('"reason":"unknown_connection"'))
    end
  end

  context "manual echo data minimization" do
    let(:private_body) { "MANUAL_PRIVATE_BODY_MUST_NOT_PERSIST" }
    let(:echo_payload) do
      { object: "whatsapp_business_account", entry: [ { id: "456", changes: [ { field: "smb_message_echoes",
        value: { metadata: { phone_number_id: "123" }, message_echoes: [ { id: "wamid-manual-private", from: "5491133333333", to: "5491122222222", timestamp: Time.current.to_i.to_s,
          type: "text", text: { body: private_body }, interactive: { body: { text: private_body } }, caption: private_body, contact_name: private_body } ] } } ] } ] }
    end

    it "drops private content before persistence, jobs and logs while preserving the pause" do
      output = StringIO.new
      capture = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(output))
      original_loggers = [ Rails.logger, ActionController::Base.logger, ActiveRecord::Base.logger, ActiveJob::Base.logger ]
      Rails.logger = ActionController::Base.logger = ActiveRecord::Base.logger = ActiveJob::Base.logger = capture
      deliver(echo_payload.to_json)
      expect(response).to have_http_status(:ok)
      event = business.whatsapp_events.sole
      expect(event.payload.keys).to contain_exactly("id", "to", "timestamp")
      expect(event.phone_number_id).to eq("123")
      expect(event.payload.to_json).not_to include(private_body)
      expect(enqueued_jobs.select { |job| job[:job] == WhatsApp::ProcessEventJob }.map { |job| job[:args] }).to eq([ [ event.id ] ])
      expect(enqueued_jobs.to_json).not_to include(private_body)
      expect(WhatsApp::CloudClient).not_to receive(:new)
      WhatsApp::ProcessEventJob.perform_now(event.id)
      expect(business.whatsapp_contacts.sole).to be_paused
      expect(business.whatsapp_deliveries).to be_empty
      expect(event.reload.payload).to eq({})
      expect(output.string).not_to include(private_body)
    ensure
      Rails.logger, ActionController::Base.logger, ActiveRecord::Base.logger, ActiveJob::Base.logger = original_loggers if original_loggers
    end

    it "pauses only the tenant identified by the echo metadata" do
      other = User.create!(email_address: "wa-echo-other-#{SecureRandom.hex(4)}@example.com", password: "password123")
        .create_business!(name: "Other salon", slug: "wa-echo-other-#{SecureRandom.hex(4)}")
      other.create_whatsapp_connection!(phone_number_id: "789", waba_id: "987", access_token: "other-test-token")
      other_contact = other.whatsapp_contacts.create!(phone: "5491122222222", last_inbound_at: Time.current)
      deliver(echo_payload.to_json)
      event = business.whatsapp_events.sole
      WhatsApp::ProcessEventJob.perform_now(event.id)
      expect(business.whatsapp_contacts.sole).to be_paused
      expect(other_contact.reload).not_to be_paused
      expect(other.whatsapp_events).to be_empty
    end

    it "preserves the body of normal incoming messages for chatbot processing" do
      deliver
      event = business.whatsapp_events.sole
      expect(event.kind).to eq("inbound")
      expect(event.payload.dig("text", "body")).to eq("Hola privado")
    end
  end
end
