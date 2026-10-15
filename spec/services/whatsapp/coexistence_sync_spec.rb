require "rails_helper"

RSpec.describe WhatsApp::SyncCoexistenceDataJob do
  around do |example|
    previous = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous
  end

  let(:business) do
    User.create!(email_address: "sync-#{SecureRandom.hex(4)}@example.com", password: "password123")
      .create_business!(name: "Sync", slug: "sync-#{SecureRandom.hex(4)}")
  end
  let(:connection) { business.create_whatsapp_connection!(phone_number_id: "123", waba_id: "456", access_token: "test-token", connected_at: Time.current, verified_at: Time.current, token_expires_at: 60.days.from_now) }
  let(:client) { instance_double(WhatsApp::CloudClient) }
  before { allow(WhatsApp::CloudClient).to receive(:new).and_return(client) }

  it "initiates both required syncs once without importing history or sending messages" do
    %w[smb_app_state_sync history].each do |type|
      expect(client).to receive(:post!).with("123/smb_app_data", { messaging_product: "whatsapp", sync_type: type }, token: "test-token").once.and_return("request_id" => "request-#{type}")
    end
    generation = connection.connected_at.iso8601(6)
    2.times { described_class.perform_now(connection.id, generation) }
    expect(connection.reload.sync_metadata.values.map { |sync| sync["state"] }).to eq(%w[accepted accepted])
    expect(business.whatsapp_deliveries).to be_empty
  end

  it "does not blindly repeat a sync after an uncertain response" do
    expect(client).to receive(:post!).with("123/smb_app_data", { messaging_product: "whatsapp", sync_type: "smb_app_state_sync" }, token: "test-token").once.and_raise(WhatsApp::CloudClient::UncertainDelivery)
    expect(client).to receive(:post!).with("123/smb_app_data", { messaging_product: "whatsapp", sync_type: "history" }, token: "test-token").once.and_return("request_id" => "request-history")
    generation = connection.connected_at.iso8601(6)
    2.times { described_class.perform_now(connection.id, generation) }
    expect(connection.reload.sync_metadata.dig("smb_app_state_sync", "state")).to eq("unknown")
  end

  it "does not execute stale jobs after reconnection or local disconnection" do
    generation = connection.connected_at.iso8601(6)
    connection.update!(connected_at: connection.connected_at + 1.second)
    expect(client).not_to receive(:post!)
    described_class.perform_now(connection.id, generation)
    connection.disconnect!
    described_class.perform_now(connection.id, connection.connected_at.iso8601(6))
  end
end
