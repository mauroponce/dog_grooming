require "rails_helper"

RSpec.describe "Sessions", type: :request do
  before { host! "localhost" }

  it "renders email and password login without a magic-link form" do
    get new_session_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    password_input = document.at_css("input[name='password']")
    password_toggle = document.at_css("button[data-password-visibility-target='button']")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(action="#{session_path}"))
    expect(response.body).to include(%(name="password"))
    expect(response.body).not_to include("Enviarme link mágico")
    expect(response.body).not_to include(%(action="#{magic_links_path}"))
    expect(password_input["type"]).to eq("password")
    expect(password_input["autocomplete"]).to eq("off")
    expect(password_input["data-password-visibility-target"]).to eq("input")
    expect(password_toggle["data-action"]).to include("password-visibility#toggle")
    expect(password_toggle["aria-pressed"]).to eq("false")
    password_icon = password_toggle.at_css("svg[data-password-visibility-target='icon']")

    expect(password_icon).to be_present
    expect(password_icon.at_css("circle[cx='12'][cy='12']")).to be_present
    expect(password_toggle["class"]).not_to include("focus:ring-brand-300")
  end

  it "redirects signed-in admins from the login form to the admin home" do
    user = create_user(role: :admin, email_prefix: "session-admin")
    Business.create!(
      owner: user,
      name: "Session Admin Center",
      slug: "session-admin-center-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )

    sign_in(user)
    get new_session_path, headers: browser_headers

    expect(response).to redirect_to(admin_root_url)
  end

  it "redirects signed-in super admins from the login form to businesses" do
    user = create_user(role: :super_admin, email_prefix: "session-super")

    sign_in(user)
    get new_session_path, headers: browser_headers

    expect(response).to redirect_to(super_admin_businesses_url)
  end

  def sign_in(user)
    session = user.sessions.create!(user_agent: browser_headers.fetch("User-Agent"), ip_address: "127.0.0.1")
    allow_any_instance_of(ApplicationController).to receive(:resume_session) do
      Current.session = session
    end
  end

  def browser_headers
    {
      "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36",
      "HTTP_USER_AGENT" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"
    }
  end

  def create_user(role:, email_prefix:)
    User.create!(
      email_address: "#{email_prefix}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: role
    )
  end
end
