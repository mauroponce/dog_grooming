require "rails_helper"

RSpec.describe "Admin Mercado Pago connections", type: :request do
  around do |example|
    previous_redirect_uri = ENV["MERCADO_PAGO_REDIRECT_URI"]
    ENV["MERCADO_PAGO_REDIRECT_URI"] = "https://public.example.com/admin/configuracion/mercadopago/callback"
    example.run
  ensure
    ENV["MERCADO_PAGO_REDIRECT_URI"] = previous_redirect_uri
  end

  it "uses the configured public redirect URI to authorize and exchange the OAuth code" do
    business = create_business
    sign_in(business.owner)
    oauth_client = instance_double(MercadoPago::OAuthClient)
    oauth_state = nil

    allow(MercadoPago::OAuthClient).to receive(:configured?).and_return(true)
    allow(MercadoPago::OAuthClient).to receive(:new).and_return(oauth_client)
    expect(oauth_client).to receive(:authorization_url) do |redirect_uri:, state:|
      oauth_state = state
      expect(redirect_uri).to eq(ENV.fetch("MERCADO_PAGO_REDIRECT_URI"))
      "https://auth.mercadopago.com/authorization"
    end

    get connect_admin_mercado_pago_connection_path, headers: browser_headers

    expect(response).to redirect_to("https://auth.mercadopago.com/authorization")

    expect(oauth_client).to receive(:exchange_code!).with(
      code: "oauth-code",
      redirect_uri: ENV.fetch("MERCADO_PAGO_REDIRECT_URI")
    ).and_return("access_token" => "TEST-access-token", "user_id" => 123)
    mercado_pago_client = instance_double(MercadoPago::Client, fetch_current_user!: {})
    allow(MercadoPago::Client).to receive(:new).and_return(mercado_pago_client)

    get callback_admin_mercado_pago_connection_path,
      params: { code: "oauth-code", state: oauth_state },
      headers: browser_headers

    expect(response).to redirect_to(admin_settings_path(settings_tab: "cuentas-de-cobro", anchor: "cuentas-de-cobro"))
    expect(business.reload.mercado_pago_connection).to be_connected
  end

  def create_business
    owner = User.create!(
      email_address: "mercado-pago-owner-#{SecureRandom.hex(4)}@example.test",
      name: "Juliana Admin",
      role: :admin
    )
    Business.create!(
      owner: owner,
      name: "Patitas Test",
      slug: "patitas-test-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 4444-4444",
      onboarding_completed_at: Time.current
    )
  end

  def sign_in(user)
    session = user.sessions.create!(user_agent: browser_headers.fetch("User-Agent"), ip_address: "127.0.0.1")
    allow_any_instance_of(ApplicationController).to receive(:resume_session) { Current.session = session }
    allow_any_instance_of(ApplicationController).to receive(:verified_request?).and_return(true)
  end

  def browser_headers
    { "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36" }
  end
end
