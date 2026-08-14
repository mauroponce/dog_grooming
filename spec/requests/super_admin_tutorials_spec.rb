require "rails_helper"

RSpec.describe "Super admin tutorials", type: :request do
  before { host! "localhost" }

  it "lets super admins create, edit, and delete tutorials" do
    super_admin = create_user(role: :super_admin, email_prefix: "tutorials-super")

    sign_in(super_admin)

    expect {
      post super_admin_tutorials_path,
        params: { tutorial: { title: "Configurar cuentas de cobro", video_url: "https://www.youtube.com/watch?v=cobros" } },
        headers: browser_headers
    }.to change(Tutorial, :count).by(1)

    tutorial = Tutorial.last
    expect(response).to redirect_to(super_admin_tutorials_path)
    expect(tutorial.title).to eq("Configurar cuentas de cobro")

    patch super_admin_tutorial_path(tutorial),
      params: { tutorial: { title: "Configurar Mercado Pago", video_url: "https://vimeo.com/123456" } },
      headers: browser_headers

    expect(response).to redirect_to(super_admin_tutorials_path)
    expect(tutorial.reload.title).to eq("Configurar Mercado Pago")
    expect(tutorial.video_url).to eq("https://vimeo.com/123456")

    expect {
      delete super_admin_tutorial_path(tutorial), headers: browser_headers
    }.to change(Tutorial, :count).by(-1)

    expect(response).to redirect_to(super_admin_tutorials_path)
  end

  it "shows validation errors for invalid video links" do
    super_admin = create_user(role: :super_admin, email_prefix: "tutorials-invalid")

    sign_in(super_admin)
    post super_admin_tutorials_path,
      params: { tutorial: { title: "Video inválido", video_url: "javascript:alert(1)" } },
      headers: browser_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("debe ser un enlace http:// o https:// válido")
  end

  it "does not allow regular admins to manage tutorials" do
    admin = create_user(role: :admin, email_prefix: "tutorials-admin")

    sign_in(admin)
    get super_admin_tutorials_path, headers: browser_headers

    expect(response).to redirect_to(root_path)
  end

  private
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
