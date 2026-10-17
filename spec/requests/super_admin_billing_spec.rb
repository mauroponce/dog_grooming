require "rails_helper"

RSpec.describe "Super admin billing", type: :request do
  before { host! "localhost:3000" }

  it "permite configurar la cuenta bancaria de Cita.pet" do
    super_admin = create_user(role: :super_admin)
    sign_in(super_admin)

    get super_admin_billing_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cuenta para recibir transferencias")
    expect(response.body).to include("Constancia bancaria")
  end

  it "no permite el panel a un admin de negocio" do
    sign_in(create_user(role: :admin))
    get super_admin_billing_path, headers: browser_headers
    expect(response).to redirect_to(root_path)
  end

  def create_user(role:)
    User.create!(email_address: "user-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
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
