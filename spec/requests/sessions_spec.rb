require "rails_helper"

RSpec.describe "Sessions", type: :request do
  before do
    host! "localhost"
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  it "renders Google as the only login method" do
    get new_session_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    google_form = document.at_css(%(form[action="/auth/google_oauth2"][method="post"]))

    expect(response).to have_http_status(:ok)
    expect(google_form).to be_present
    expect(google_form["data-turbo"]).to eq("false")
    expect(response.body).to include("Ingresar con Google")
    expect(document.at_css("input[name='password']")).to be_nil
    expect(document.at_css("input[name='email_address']")).to be_nil
  end

  it "starts an internal session for a Google identity linked to a user" do
    user = create_user(role: :admin, email_prefix: "session-admin", google_uid: "google-admin-uid")
    Business.create!(owner: user, name: "Session Admin Center", slug: "session-admin-center-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-5555", onboarding_completed_at: Time.current)

    authenticate_with_google(uid: "google-admin-uid", email: user.email_address)

    expect(response).to redirect_to(admin_root_url)
    expect(user.reload.last_login_provider).to eq("google")
  end

  it "links a preprovisioned account only when Google verifies the same email" do
    user = create_user(role: :admin, email_prefix: "preprovisioned")
    Business.create!(owner: user, name: "Preprovisioned", slug: "preprovisioned-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-5555", onboarding_completed_at: Time.current)

    authenticate_with_google(uid: "google-preprovisioned", email: user.email_address)

    expect(response).to redirect_to(admin_root_url)
    expect(user.reload).to have_attributes(google_uid: "google-preprovisioned", last_login_provider: "google")
  end

  it "does not authenticate an unknown Google email" do
    authenticate_with_google(uid: "unknown", email: "unknown@example.com")

    expect(response).to redirect_to(new_session_url)
    expect(flash[:alert]).to include("No encontramos")
  end

  it "rejects a Google identity whose email is not verified" do
    user = create_user(role: :admin, email_prefix: "unverified", google_uid: "google-unverified")

    authenticate_with_google(uid: "google-unverified", email: user.email_address, email_verified: false)

    expect(response).to redirect_to(new_session_url)
    expect(flash[:alert]).to include("No pudimos verificar")
  end

  it "rejects disabled users" do
    user = create_user(role: :admin, email_prefix: "disabled", google_uid: "google-disabled")
    user.update!(disabled_at: Time.current)

    authenticate_with_google(uid: "google-disabled", email: user.email_address)

    expect(response).to redirect_to(new_session_url)
    expect(flash[:alert]).to include("deshabilitado")
  end

  def omniauth_env(uid:, email:, email_verified: true)
    {
      "omniauth.auth" => {
        "provider" => "google_oauth2",
        "uid" => uid,
        "info" => { "email" => email, "name" => "Mauro Ponce" },
        "extra" => { "raw_info" => { "email_verified" => email_verified } }
      }
    }
  end

  def authenticate_with_google(uid:, email:, email_verified: true)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(omniauth_env(uid:, email:, email_verified:).fetch("omniauth.auth"))
    get "/auth/google_oauth2/callback"
  end

  def browser_headers
    {
      "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36",
      "HTTP_USER_AGENT" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"
    }
  end

  def create_user(role:, email_prefix:, google_uid: nil)
    User.create!(email_address: "#{email_prefix}-#{SecureRandom.hex(4)}@example.com", password: "password123", google_uid:, role: role)
  end
end
