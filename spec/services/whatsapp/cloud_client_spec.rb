require "rails_helper"

RSpec.describe WhatsApp::CloudClient do
  it "reports structured error codes without exposing Meta response details or tokens" do
    response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
    allow(response).to receive(:body).and_return({ error: { code: 190, error_subcode: 463, message: "private-provider-details" } }.to_json)
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    expect { described_class.new.get!("test", token: "private-test-token") }.to raise_error(described_class::Error) do |error|
      expect(error.code).to eq(190)
      expect(error.subcode).to eq(463)
      expect(error).to be_authorization_error
      expect(error.message).not_to include("private-provider-details", "private-test-token")
    end
  end

  it "sanitizes transport failures that may otherwise contain a credential-bearing URL" do
    allow(Net::HTTP).to receive(:start).and_raise(SocketError, "URL with private-token")
    expect { described_class.new.get!("test", token: "private-token") }.to raise_error(described_class::UncertainDelivery) do |error|
      expect(error.message).not_to include("private-token")
    end
  end
end
