require "rails_helper"

RSpec.describe WhatsApp::ConnectBusiness do
  around do |example|
    original = ENV.to_h.slice("META_APP_ID", "META_APP_SECRET", "META_EMBEDDED_SIGNUP_V4_CONFIRMED")
    ENV["META_APP_ID"] = "app-id"
    ENV["META_APP_SECRET"] = "app-secret"
    ENV["META_EMBEDDED_SIGNUP_V4_CONFIRMED"] = "true"
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    %w[META_APP_ID META_APP_SECRET META_EMBEDDED_SIGNUP_V4_CONFIRMED].each { |key| original.key?(key) ? ENV[key] = original[key] : ENV.delete(key) }
    ActiveJob::Base.queue_adapter = previous_adapter
  end
  let(:business) do
    owner = User.create!(email_address: "meta-#{SecureRandom.hex(4)}@example.com", password: "password123")
    owner.create_business!(name: "Pichipurris", slug: "meta-#{SecureRandom.hex(4)}", contact_phone: "5491111111111")
  end
  let(:client) { instance_double(WhatsApp::CloudClient) }
  let(:details) do
    { "is_valid" => true, "app_id" => "app-id", "expires_at" => 60.days.from_now.to_i,
      "scopes" => described_class::PERMISSIONS,
      "granular_scopes" => described_class::PERMISSIONS.map { |permission| { "scope" => permission, "target_ids" => [ "456" ] } } }
  end

  def connect(**attributes)
    described_class.call(**{ business: business, code: "one-use-code", event: described_class::FINISH_EVENT, waba_id: "456", phone_number_id: "123" }.merge(attributes))
  end

  before do
    allow(WhatsApp::CloudClient).to receive(:new).and_return(client)
    allow(client).to receive(:get!).with(a_string_starting_with("oauth/access_token?"), token: "app-id|app-secret").and_return("access_token" => "business-token")
    allow(client).to receive(:get!).with("debug_token?input_token=business-token", token: "app-id|app-secret").and_return("data" => details)
    allow(client).to receive(:get!).with("456/phone_numbers?fields=id&limit=100", token: "business-token").and_return("data" => [ { "id" => "123" } ])
    allow(client).to receive(:get!).with("123?fields=id,is_on_biz_app,platform_type", token: "business-token").and_return("id" => "123", "is_on_biz_app" => true, "platform_type" => "CLOUD_API")
  end

  it "checks the phone against the accessible WABA and requires coexistence before saving encrypted credentials" do
    expect(client).to receive(:post!).with("456/subscribed_apps", {}, token: "business-token").and_return("success" => true)
    connection = connect
    expect(connection.access_token).to eq("business-token")
    expect(connection.access_token_ciphertext).not_to include("business-token")
    expect(connection).to be_connected
    expect(connection.automation_enabled).to be(false)
    expect(connection.token_expires_at.to_i).to eq(details["expires_at"])
    expect(connection.verified_at).to be_present
    expect(connection.subscribed_at).to be_present
  end

  it "does not trust phone IDs received from the browser alone" do
    allow(client).to receive(:get!).with("456/phone_numbers?fields=id&limit=100", token: "business-token").and_return("data" => [ { "id" => "999" } ])
    expect(client).not_to receive(:post!)
    expect { connect }.to raise_error(ArgumentError, /número/)
    expect(business.reload.whatsapp_connection).to be_nil
  end

  it "discovers missing IDs exclusively from the grant and WABA, never global test credentials" do
    expect(client).to receive(:post!).with("456/subscribed_apps", {}, token: "business-token").and_return("success" => true)
    expect(connect(waba_id: nil, phone_number_id: nil)).to have_attributes(waba_id: "456", phone_number_id: "123")
  end

  it "refuses non-Coexistence completion events and unconfirmed configurations without exchanging a code" do
    expect(client).not_to receive(:get!)
    expect { connect(event: "FINISH") }.to raise_error(ArgumentError, /coexistencia/)
    ENV["META_EMBEDDED_SIGNUP_V4_CONFIRMED"] = "false"
    expect { connect }.to raise_error(ArgumentError, /v4/)
  end

  it "rejects invalid app grants, missing permissions, expired grants and ungranted WABAs" do
    expect(client).not_to receive(:post!)
    details["app_id"] = "other-app"
    expect { connect }.to raise_error(ArgumentError, /permisos/)
    details["app_id"] = "app-id"
    details["scopes"] = []
    expect { connect }.to raise_error(ArgumentError, /permisos/)
    details["scopes"] = described_class::PERMISSIONS
    expect { connect(waba_id: "999") }.to raise_error(ArgumentError, /WABA/)
    details["expires_at"] = 1.minute.ago.to_i
    expect { connect }.to raise_error(ArgumentError, /vencieron/)
  end

  it "rejects a Cloud API-only line without subscribing, registering or migrating it" do
    allow(client).to receive(:get!).with("123?fields=id,is_on_biz_app,platform_type", token: "business-token").and_return("id" => "123", "is_on_biz_app" => false, "platform_type" => "CLOUD_API")
    expect(client).not_to receive(:post!)
    expect { connect }.to raise_error(ArgumentError, /coexistencia/)
  end

  it "requires explicit selection when multiple numbers are authorized" do
    allow(client).to receive(:get!).with("456/phone_numbers?fields=id&limit=100", token: "business-token").and_return("data" => [ { "id" => "123" }, { "id" => "789" } ])
    expect(client).not_to receive(:post!)
    expect { connect(phone_number_id: nil) }.to raise_error(ArgumentError, /único número/)
  end

  it "does not follow a paging URL that could leak tokens to another host" do
    allow(client).to receive(:get!).with("456/phone_numbers?fields=id&limit=100", token: "business-token").and_return("data" => [], "paging" => { "next" => "https://untrusted.example", "cursors" => { "after" => "next-cursor" } })
    expect(client).to receive(:get!).with("456/phone_numbers?fields=id&limit=100&after=next-cursor", token: "business-token").and_return("data" => [ { "id" => "123" } ])
    expect(client).to receive(:post!).with("456/subscribed_apps", {}, token: "business-token").and_return("success" => true)
    expect(connect).to be_connected
  end

  it "does not take a phone already connected to a different tenant" do
    owner = User.create!(email_address: "other-#{SecureRandom.hex(4)}@example.com", password: "password123")
    other = owner.create_business!(name: "Other", slug: "other-#{SecureRandom.hex(4)}")
    existing = other.create_whatsapp_connection!(phone_number_id: "123", waba_id: "456", access_token: "other-token")
    expect(client).not_to receive(:post!)
    expect { connect }.to raise_error(ArgumentError, /otra peluquería/)
    expect(existing.reload.access_token).to eq("other-token")
  end

  it "preserves a working connection if subscription is not confirmed" do
    existing = business.create_whatsapp_connection!(phone_number_id: "789", waba_id: "987", access_token: "previous-token")
    expect(client).to receive(:post!).with("456/subscribed_apps", {}, token: "business-token").and_return("success" => false)
    expect { connect }.to raise_error(WhatsApp::CloudClient::Error)
    expect(existing.reload).to have_attributes(phone_number_id: "789", waba_id: "987")
    expect(existing.access_token).to eq("previous-token")
  end

  it "does not request one-shot history sync again when renewing credentials for the same line" do
    metadata = { "history" => { "state" => "accepted", "request_id" => "previous-history" } }
    business.create_whatsapp_connection!(phone_number_id: "123", waba_id: "456", access_token: "previous-token", sync_metadata: metadata)
    expect(client).to receive(:post!).with("456/subscribed_apps", {}, token: "business-token").and_return("success" => true)
    expect(connect.sync_metadata).to eq(metadata)
  end

  it "marks expired and revoked credentials disconnected without inventing refresh tokens" do
    connection = business.create_whatsapp_connection!(phone_number_id: "123", waba_id: "456", access_token: "token", token_expires_at: 1.minute.ago)
    expect(connection).not_to be_connected
    connection.update!(token_expires_at: 5.days.from_now)
    expect(connection).to be_connected
    expect(connection).to be_reconnect_soon
    connection.update!(authorization_failed_at: Time.current)
    expect(connection).not_to be_connected
  end
end
