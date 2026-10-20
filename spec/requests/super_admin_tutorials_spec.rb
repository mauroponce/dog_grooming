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

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("debe ser un enlace http:// o https:// válido")
  end

  it "does not allow regular admins to manage tutorials" do
    admin = create_user(role: :admin, email_prefix: "tutorials-admin")

    sign_in(admin)
    get super_admin_tutorials_path, headers: browser_headers

    expect(response).to redirect_to(root_path)

    patch reorder_super_admin_tutorials_path,
      params: { tutorial_ids: [] },
      as: :json,
      headers: browser_headers

    expect(response).to redirect_to(root_path)
  end

  it "keeps usage below tutorials in the super admin navigation" do
    super_admin = create_user(role: :super_admin, email_prefix: "tutorials-navigation")

    sign_in(super_admin)
    get super_admin_tutorials_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    navigation_links = document.css("aside nav a").map { |link| link["href"] }
    tutorial_link = document.at_css("aside nav a[href='#{super_admin_tutorials_path}']")

    expect(navigation_links).to eq([
      super_admin_businesses_path,
      super_admin_billing_path,
      super_admin_tutorials_path,
      super_admin_usage_path
    ])
    expect(tutorial_link.at_css("svg")).to be_present
    expect(tutorial_link.text).not_to include("▶")
  end

  it "persists the tutorial order selected by a super admin" do
    super_admin = create_user(role: :super_admin, email_prefix: "tutorials-order")
    first_tutorial = Tutorial.create!(title: "Primer tutorial", video_url: "https://example.com/first", sort_order: 0)
    second_tutorial = Tutorial.create!(title: "Segundo tutorial", video_url: "https://example.com/second", sort_order: 1)
    third_tutorial = Tutorial.create!(title: "Tercer tutorial", video_url: "https://example.com/third", sort_order: 2)

    sign_in(super_admin)
    patch reorder_super_admin_tutorials_path,
      params: { tutorial_ids: [ third_tutorial.id, first_tutorial.id, second_tutorial.id ] },
      as: :json,
      headers: browser_headers

    expect(response).to have_http_status(:no_content)
    expect(Tutorial.ordered.pluck(:id)).to eq([ third_tutorial.id, first_tutorial.id, second_tutorial.id ])

    get super_admin_tutorials_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    expect(document.css("[data-tutorial-sort-target='item']").map { |item| item["data-tutorial-id"].to_i }).to eq([ third_tutorial.id, first_tutorial.id, second_tutorial.id ])
    expect(document.css("[data-tutorial-sort-handle]").size).to eq(3)
  end

  it "rejects incomplete tutorial orders without changing the current order" do
    super_admin = create_user(role: :super_admin, email_prefix: "tutorials-invalid-order")
    first_tutorial = Tutorial.create!(title: "Primer tutorial", video_url: "https://example.com/first", sort_order: 0)
    second_tutorial = Tutorial.create!(title: "Segundo tutorial", video_url: "https://example.com/second", sort_order: 1)
    initial_order = Tutorial.ordered.pluck(:id)

    sign_in(super_admin)
    patch reorder_super_admin_tutorials_path,
      params: { tutorial_ids: [ first_tutorial.id, first_tutorial.id ] },
      as: :json,
      headers: browser_headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch("error")).to eq("El orden de tutoriales no es válido.")
    expect(Tutorial.ordered.pluck(:id)).to eq(initial_order)
    expect(second_tutorial.reload.sort_order).to eq(1)
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
