require "rails_helper"

RSpec.describe MercadoPago::OAuthClient do
  around do |example|
    keys = ENV.keys.grep(/\A(?:MERCADO_PAGO|MP_)/)
    original_values = keys.index_with { |key| ENV[key] }
    keys.each { |key| ENV.delete(key) }

    example.run
  ensure
    keys.each { |key| ENV.delete(key) }
    original_values.each { |key, value| ENV[key] = value }
  end

  it "requests a test token when Mercado Pago is in test mode" do
    ENV["MERCADO_PAGO_ENV"] = "test"
    ENV["MERCADO_PAGO_CLIENT_ID"] = "client-id"
    ENV["MERCADO_PAGO_CLIENT_SECRET"] = "client-secret"

    client = described_class.new
    expect(client).to receive(:post_json).with(
      "/oauth/token",
      hash_including(test_token: true, client_id: "client-id", client_secret: "client-secret")
    ).and_return({})

    client.exchange_code!(code: "oauth-code", redirect_uri: "https://example.com/callback")
  end

  it "builds the authorization url with the configured app client id in test mode" do
    ENV["MERCADO_PAGO_ENV"] = "test"
    ENV["MERCADO_PAGO_CLIENT_ID"] = "app-client-id"
    ENV["MERCADO_PAGO_CLIENT_SECRET"] = "client-secret"
    ENV["MERCADO_PAGO_TEST_ACCESS_TOKEN"] = "APP_USR-5154825365594110-072917-token-user"

    url = described_class.new.authorization_url(redirect_uri: "https://example.com/callback", state: "secure-state")

    expect(url).to include("client_id=app-client-id")
    expect(url).to include("redirect_uri=https%3A%2F%2Fexample.com%2Fcallback")
    expect(url).to include("state=secure-state")
  end
end
