require "rails_helper"

RSpec.describe WhatsApp::ConnectBusiness do
  around do |example|
    original = ENV.to_h.slice("META_APP_ID", "META_APP_SECRET")
    ENV["META_APP_ID"] = "app-id"
    ENV["META_APP_SECRET"] = "app-secret"
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    %w[META_APP_ID META_APP_SECRET].each { |key| original.key?(key) ? ENV[key] = original[key] : ENV.delete(key) }
    ActiveJob::Base.queue_adapter = previous_adapter
  end
  let(:business) do
    owner = User.create!(email_address: "meta-#{SecureRandom.hex(4)}@example.com", password: "password123")
    owner.create_business!(name: "Pichipurris", slug: "meta-#{SecureRandom.hex(4)}", contact_phone: "5491111111111")
  end
  let(:client) { instance_double(WhatsApp::CloudClient) }

  before do
    allow(WhatsApp::CloudClient).to receive(:new).and_return(client)
    allow(client).to receive(:get!).with(a_string_starting_with("oauth/access_token?"), token: "app-id|app-secret").and_return("access_token" => "business-token")
  end

  it "checks the phone against the accessible WABA and requires coexistence before saving encrypted credentials" do
    allow(client).to receive(:get!).with("456/phone_numbers?fields=id,is_on_biz_app&limit=100", token: "business-token").and_return("data" => [ { "id" => "123", "is_on_biz_app" => true } ])
    expect(client).to receive(:post!).with("456/subscribed_apps", {}, token: "business-token").and_return("success" => true)
    connection = described_class.call(business: business, code: "one-use-code", waba_id: "456", phone_number_id: "123")
    expect(connection.access_token).to eq("business-token")
    expect(connection.access_token_ciphertext).not_to include("business-token")
    expect(connection).to be_connected
  end

  it "does not trust phone IDs received from the browser alone" do
    allow(client).to receive(:get!).with("456/phone_numbers?fields=id,is_on_biz_app&limit=100", token: "business-token").and_return("data" => [ { "id" => "999", "is_on_biz_app" => true } ])
    expect(client).not_to receive(:post!)
    expect { described_class.call(business: business, code: "one-use-code", waba_id: "456", phone_number_id: "123") }.to raise_error(ArgumentError, /coexistencia/)
    expect(business.reload.whatsapp_connection).to be_nil
  end
end
