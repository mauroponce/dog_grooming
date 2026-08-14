require "rails_helper"

RSpec.describe MercadoPagoConnection do
  describe "#assign_account_profile!" do
    it "stores the Mercado Pago account profile returned by the API" do
      connection = described_class.new

      connection.assign_account_profile!(
        "id" => 357_830_1779,
        "email" => "duenia@example.com",
        "nickname" => "DUENIA_TEST",
        "site_id" => "MLA",
        "status" => {
          "site_status" => "active",
          "mercadopago_account_type" => "personal"
        }
      )

      expect(connection.mercado_pago_user_id).to eq("3578301779")
      expect(connection.mercado_pago_email).to eq("duenia@example.com")
      expect(connection.mercado_pago_nickname).to eq("DUENIA_TEST")
      expect(connection.metadata).to include(
        "account_site_id" => "MLA",
        "account_status" => "active",
        "account_type" => "personal"
      )
    end
  end

  describe "#mercado_pago_account_label" do
    it "prefers email over nickname and user id" do
      connection = described_class.new(
        mercado_pago_user_id: "3578301779",
        mercado_pago_nickname: "DUENIA_TEST",
        mercado_pago_email: "duenia@example.com"
      )

      expect(connection.mercado_pago_account_label).to eq("duenia@example.com")
    end

    it "falls back to nickname and then user id" do
      expect(described_class.new(mercado_pago_nickname: "DUENIA_TEST", mercado_pago_user_id: "3578301779").mercado_pago_account_label).to eq("DUENIA_TEST")
      expect(described_class.new(mercado_pago_user_id: "3578301779").mercado_pago_account_label).to eq("3578301779")
    end
  end

  describe "#available_for_current_environment?" do
    it "requires a production reconnection for a known test OAuth token" do
      connection = described_class.new(metadata: { "live_mode" => false })
      connection.access_token = "TEST-test-token"

      allow(MercadoPago::Credentials).to receive(:test?).and_return(false)

      expect(connection).to be_test_connection
      expect(connection.requires_production_reconnection?).to be(true)
      expect(connection).not_to be_available_for_current_environment
    end
  end
end
