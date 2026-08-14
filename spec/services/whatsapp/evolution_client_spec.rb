require "rails_helper"

RSpec.describe WhatsApp::EvolutionClient do
  describe "#setup_instance" do
    it "recreates a disconnected instance without a linked number" do
      client = described_class.new(base_url: "http://evolution.test", api_key: "secret", instance_name: "dog-grooming-main")
      created_response = response_hash(status: 201, body: { "qrcode" => { "base64" => "new-qr" } })

      allow(client).to receive(:post)
        .with("/instance/create", hash_including(instanceName: "dog-grooming-main"))
        .and_return(instance_in_use_response, created_response)
      allow(client).to receive(:get)
        .with("/instance/fetchInstances")
        .and_return(fetch_disconnected_instance_response)
      allow(client).to receive(:get)
        .with("/instance/connectionState/dog-grooming-main")
        .and_return(connection_state_response("connecting"))
      allow(client).to receive(:delete)
        .with("/instance/delete/dog-grooming-main")
        .and_return(response_hash(status: 200, body: { "deleted" => true }))

      expect(client.setup_instance).to eq(created_response)
    end

    it "keeps an existing linked instance and only updates the webhook" do
      client = described_class.new(base_url: "http://evolution.test", api_key: "secret", instance_name: "dog-grooming-main")
      webhook_response = response_hash(status: 201, body: { "enabled" => true })

      allow(client).to receive(:post)
        .with("/instance/create", hash_including(instanceName: "dog-grooming-main"))
        .and_return(instance_in_use_response)
      allow(client).to receive(:get)
        .with("/instance/fetchInstances")
        .and_return(fetch_linked_instance_response)
      allow(client).to receive(:post)
        .with("/webhook/set/dog-grooming-main", anything)
        .and_return(webhook_response)
      expect(client).not_to receive(:delete)

      expect(client.setup_instance).to eq(webhook_response)
    end
  end

  describe "#connect_instance" do
    it "creates the instance when QR is requested and the instance does not exist" do
      client = described_class.new(base_url: "http://evolution.test", api_key: "secret", instance_name: "dog-grooming-main")
      created_response = response_hash(status: 201, body: { "qrcode" => { "base64" => "new-qr" } })

      allow(client).to receive(:get)
        .with("/instance/connect/dog-grooming-main")
        .and_return(missing_instance_response)
      allow(client).to receive(:post)
        .with("/instance/create", hash_including(instanceName: "dog-grooming-main"))
        .and_return(created_response)
      expect(client).not_to receive(:delete)

      expect(client.connect_instance).to eq(created_response)
    end

    it "recreates a disconnected instance when Evolution returns an empty QR response" do
      client = described_class.new(base_url: "http://evolution.test", api_key: "secret", instance_name: "dog-grooming-main")
      created_response = response_hash(status: 201, body: { "qrcode" => { "base64" => "new-qr" } })

      allow(client).to receive(:get)
        .with("/instance/connect/dog-grooming-main")
        .and_return(response_hash(status: 200, body: { "count" => 0 }))
      allow(client).to receive(:get)
        .with("/instance/fetchInstances")
        .and_return(fetch_disconnected_instance_response)
      allow(client).to receive(:get)
        .with("/instance/connectionState/dog-grooming-main")
        .and_return(connection_state_response("connecting"))
      allow(client).to receive(:delete)
        .with("/instance/delete/dog-grooming-main")
        .and_return(response_hash(status: 200, body: { "deleted" => true }))
      allow(client).to receive(:post)
        .with("/instance/create", hash_including(instanceName: "dog-grooming-main"))
        .and_return(created_response)

      expect(client.connect_instance).to eq(created_response)
    end
  end

  def response_hash(status:, body:)
    {
      success: status.between?(200, 299),
      status: status,
      body: body,
      sanitized_body: body
    }
  end

  def instance_in_use_response
    response_hash(
      status: 403,
      body: { "response" => { "message" => [ "The instance name is already in use" ] } }
    )
  end

  def connection_state_response(state)
    response_hash(
      status: 200,
      body: { "instance" => { "instanceName" => "dog-grooming-main", "state" => state } }
    )
  end

  def missing_instance_response
    response_hash(
      status: 404,
      body: { "response" => { "message" => [ 'The "dog-grooming-main" instance does not exist' ] } }
    )
  end

  def fetch_disconnected_instance_response
    response_hash(
      status: 200,
      body: [
        {
          "name" => "dog-grooming-main",
          "connectionStatus" => "close",
          "ownerJid" => nil,
          "number" => nil,
          "profile" => {}
        }
      ]
    )
  end

  def fetch_linked_instance_response
    response_hash(
      status: 200,
      body: [
        {
          "name" => "dog-grooming-main",
          "connectionStatus" => "open",
          "ownerJid" => "5491112345678@s.whatsapp.net",
          "number" => "5491112345678"
        }
      ]
    )
  end
end
