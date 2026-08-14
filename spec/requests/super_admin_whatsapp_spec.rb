require "rails_helper"

RSpec.describe "Super admin WhatsApp", type: :request do
  before { host! "localhost" }

  it "renders the dashboard when Evolution returns an instance without a number" do
    user = create_user(role: :super_admin, email_prefix: "super-whatsapp")
    client = instance_double(
      WhatsApp::EvolutionClient,
      instance_name: "dog-grooming-main",
      configured?: true,
      connection_state: {
        success: true,
        status: 200,
        body: { "instance" => { "state" => "close" } },
        sanitized_body: { "instance" => { "state" => "close" } }
      },
      fetch_instances: {
        success: true,
        status: 200,
        body: [
          {
            "name" => "dog-grooming-main",
            "owner" => nil,
            "profile" => {}
          }
        ],
        sanitized_body: [
          {
            "name" => "dog-grooming-main",
            "owner" => nil,
            "profile" => {}
          }
        ]
      }
    )

    allow(WhatsApp::EvolutionClient).to receive(:new).and_return(client)
    sign_in(user)

    get super_admin_whatsapp_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Evolution API")
    expect(response.body).to include("No disponible")
    expect(response.body).to include("Evolution no informó el número.")
  end

  def sign_in(user)
    session = user.sessions.create!(user_agent: browser_headers.fetch("User-Agent"), ip_address: "127.0.0.1")
    allow_any_instance_of(ApplicationController).to receive(:resume_session) do
      Current.session = session
    end
    allow_any_instance_of(ApplicationController).to receive(:verified_request?).and_return(true)
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
