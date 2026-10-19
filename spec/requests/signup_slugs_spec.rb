require "rails_helper"

RSpec.describe "Registro", type: :request do
  before do
    host! "localhost"
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  it "creates a dog grooming business from a verified Google identity and sends the owner to onboarding" do
    google_identity = omniauth_env(uid: "google-signup-#{SecureRandom.hex(4)}", email: "mauro-#{SecureRandom.hex(4)}@example.com")

    authenticate_with_google(google_identity, origin: "registration")
    post registro_path, params: { registration: registration_params }, headers: browser_headers

    business = Business.order(:created_at).last
    expect(response).to redirect_to(onboarding_schedule_path)
    expect(business.owner).to have_attributes(email_address: google_identity.dig("omniauth.auth", "info", "email"), google_uid: google_identity.dig("omniauth.auth", "uid"), last_login_provider: "google")
    expect(business.industry).to eq("dog_grooming")
    expect(business.trial_ends_at.to_date).to eq((business.trial_started_at + 14.days).to_date)
    expect(business.subscription.amount_cents).to eq(3_500_000)
    expect(business.onboarding_complete?).to be(false)
    expect(business.services.count).to eq(3)
    expect(business.simultaneous_capacity).to eq(1)
    expect(business.enabled_payment_methods).to eq([ "manual_transfer" ])
    expect(business.employee_memberships.available_for_booking).to be_empty
  end

  it "does not expose the registration form until Google returned a verified identity" do
    get registro_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    google_form = document.at_css(%(form[action="/auth/google_oauth2?origin=registration"][method="post"]))

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Continuar con Google")
    expect(response.body).not_to include("name=\"registration[business_name]\"")
    expect(google_form["data-turbo"]).to eq("false")
  end

  it "keeps the selected PRO plan after Google authentication" do
    authenticate_with_google(omniauth_env(uid: "google-pro-#{SecureRandom.hex(4)}", email: "pro-#{SecureRandom.hex(4)}@example.com"), origin: "registration")
    post registro_path, params: { registration: registration_params(plan_selected: "pro", business_name: "Patitas PRO") }, headers: browser_headers

    expect(response).to redirect_to(onboarding_schedule_path)
    expect(Business.order(:created_at).last.subscription).to have_attributes(plan_selected: "pro", amount_cents: 4_500_000)
  end

  it "exposes slug availability" do
    get signup_slug_availability_path, params: { slug: "patitas-nuevo" }, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include("available" => true, "slug" => "patitas-nuevo")
  end

  def omniauth_env(uid:, email:)
    {
      "omniauth.auth" => {
        "provider" => "google_oauth2",
        "uid" => uid,
        "info" => { "email" => email, "name" => "Mauro Ponce" },
        "extra" => { "raw_info" => { "email_verified" => true } }
      }
    }
  end

  def authenticate_with_google(environment, origin: nil)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(environment.fetch("omniauth.auth"))
    get "/auth/google_oauth2/callback", env: { "omniauth.origin" => origin }
  end

  def registration_params(plan_selected: "basic", business_name: "Patitas Felices")
    {
      business_name: business_name,
      owner_name: "Mauro Ponce",
      contact_phone: "+54 9 11 5555 5555",
      slug: "patitas-#{SecureRandom.hex(4)}",
      plan_selected: plan_selected
    }
  end

  def browser_headers
    { "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36" }
  end
end
