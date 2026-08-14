require "rails_helper"

RSpec.describe MercadoPago::Credentials do
  around do |example|
    keys = ENV.keys.grep(/\A(?:MERCADO_PAGO|MP_)/)
    original_values = keys.index_with { |key| ENV[key] }
    keys.each { |key| ENV.delete(key) }

    example.run
  ensure
    keys.each { |key| ENV.delete(key) }
    original_values.each { |key, value| ENV[key] = value }
  end

  it "uses production-specific credentials by default" do
    ENV["MERCADO_PAGO_PUBLIC_KEY"] = "legacy-public"
    ENV["MERCADO_PAGO_PRODUCTION_PUBLIC_KEY"] = "production-public"
    ENV["MERCADO_PAGO_TEST_PUBLIC_KEY"] = "test-public"

    expect(described_class.environment).to eq("production")
    expect(described_class.public_key).to eq("production-public")
  end

  it "uses test-specific credentials in test mode" do
    ENV["MERCADO_PAGO_ENV"] = "test"
    ENV["MERCADO_PAGO_PUBLIC_KEY"] = "legacy-public"
    ENV["MERCADO_PAGO_PRODUCTION_PUBLIC_KEY"] = "production-public"
    ENV["MERCADO_PAGO_TEST_PUBLIC_KEY"] = "test-public"

    expect(described_class.environment).to eq("test")
    expect(described_class.public_key).to eq("test-public")
  end

  it "uses the generic OAuth client id before inferring one from a test access token" do
    ENV["MERCADO_PAGO_ENV"] = "test"
    ENV["MERCADO_PAGO_CLIENT_ID"] = "app-client-id"
    ENV["MERCADO_PAGO_TEST_ACCESS_TOKEN"] = "APP_USR-5154825365594110-072917-token-user"

    expect(described_class.client_id).to eq("app-client-id")
  end

  it "uses an environment-specific OAuth client id before the generic one" do
    ENV["MERCADO_PAGO_CLIENT_ID"] = "generic-client-id"
    ENV["MERCADO_PAGO_PRODUCTION_CLIENT_ID"] = "production-client-id"
    ENV["MERCADO_PAGO_PRODUCTION_ACCESS_TOKEN"] = "APP_USR-6124042586336757-072917-token-user"

    expect(described_class.client_id).to eq("production-client-id")
  end

  it "infers the client id from the access token when no OAuth client id is configured" do
    ENV["MERCADO_PAGO_ENV"] = "test"
    ENV["MERCADO_PAGO_TEST_ACCESS_TOKEN"] = "APP_USR-5154825365594110-072917-token-user"

    expect(described_class.client_id).to eq("5154825365594110")
  end
end
