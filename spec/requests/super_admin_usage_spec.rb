require "rails_helper"

RSpec.describe "Super admin usage", type: :request do
  before do
    host! "localhost"
    allow_any_instance_of(SuperAdmin::Usage::R2AnalyticsClient).to receive(:snapshot).and_return(
      {
        configured: false,
        buckets: [],
        error: "Configurá Cloudflare para consultar métricas oficiales.",
        fetched_at: Time.current
      }
    )
  end

  it "shows R2 and Gemini usage to super admins" do
    super_admin = create_user(role: :super_admin, email_prefix: "usage-super")
    business = create_business(name: "Usage Center")
    AiApiUsageEvent.create!(
      business: business,
      provider: "gemini",
      feature: "service_description",
      model: "gemini-flash-lite-latest",
      request_started_at: Time.current,
      request_finished_at: Time.current,
      status: "success",
      prompt_tokens: 120,
      completion_tokens: 80,
      total_tokens: 200,
      estimated_cost_usd: 0.0001
    )
    blob = ActiveStorage::Blob.create!(
      key: "usage/#{SecureRandom.hex(12)}",
      filename: "usage.png",
      byte_size: 2.megabytes,
      checksum: "checksum",
      content_type: "image/png",
      service_name: "r2"
    )
    ActiveStorage::Attachment.create!(name: "logo", record: business, blob: blob)

    sign_in(super_admin)
    get super_admin_usage_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Uso y costos")
    expect(response.body).to include("Cloudflare R2")
    expect(response.body).to include("Gemini API")
    expect(response.body).to include("Service description")
    expect(response.body).to include("Usage Center")
    expect(response.body).to include("2 MB")
  end

  it "does not allow regular admins" do
    admin = create_user(role: :admin, email_prefix: "usage-admin")

    sign_in(admin)
    get super_admin_usage_path, headers: browser_headers

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

    def create_business(name:)
      owner = create_user(role: :admin, email_prefix: "usage-owner")
      Business.create!(
        owner: owner,
        name: name,
        slug: "#{name.parameterize}-#{SecureRandom.hex(4)}",
        onboarding_completed_at: Time.current
      )
    end
end
