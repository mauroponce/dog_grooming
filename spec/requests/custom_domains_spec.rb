require "rails_helper"

RSpec.describe "Custom domains", type: :request do
  let(:domain) { "reserva.aura.com.ar" }

  it "serves a center at its own host without its slug in public links" do
    business = create_business(custom_domain: domain, custom_domain_enabled: true)
    service = business.services.create!(
      name: "Consulta inicial",
      slug: "consulta-inicial",
      category: "Facial",
      description: "Evaluación inicial.",
      duration_minutes: 30,
      price_cents: 0,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )

    host! domain
    get "/", headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/#{service.slug}")
    expect(response.body).not_to include("/#{business.slug}/#{service.slug}")
    expect(PublicUrls.url(:business, business)).to eq("http://#{domain}/")
    expect(PublicUrls.url(:short_service, business, service.slug)).to eq("http://#{domain}/facial/#{service.slug}")
  end

  it "keeps the platform slug URL working for the same center" do
    business = create_business(custom_domain: domain, custom_domain_enabled: true)

    host! "www.example.com"
    get public_business_path(business.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
  end

  it "uses category URLs without the business slug on a complete custom website" do
    business = create_business(custom_domain: domain, custom_domain_enabled: true)
    business.update!(public_site_mode: "full_website")
    service = business.services.create!(
      name: "Depilación láser",
      slug: "depilacion-laser",
      category: "Depilación",
      duration_minutes: 30,
      price_cents: 15_000,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )

    host! domain
    get "/", headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/depilacion")
    expect(response.body).not_to include("/#{business.slug}/depilacion")

    get "/#{service.service_category.slug}", headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/#{service.service_category.slug}/#{service.slug}")

    get "/#{service.service_category.slug}/#{service.slug}", headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar fecha y hora")
  end

  it "does not expose the admin login on a customer domain" do
    create_business(custom_domain: domain, custom_domain_enabled: true)

    host! domain
    get "/acceder", headers: browser_headers

    expect(response).to have_http_status(:not_found)
  end

  it "only authorizes active domains for Caddy certificates" do
    business = create_business(custom_domain: domain, custom_domain_enabled: true)
    inactive_business = create_business(custom_domain: "turnos.inactivo.com.ar", custom_domain_enabled: false)

    host! "web"
    get "/internal/caddy/tls-permission", params: { domain: business.custom_domain }
    expect(response).to have_http_status(:ok)

    get "/internal/caddy/tls-permission", params: { domain: inactive_business.custom_domain }
    expect(response).to have_http_status(:not_found)

    host! "www.example.com"
    get "/internal/caddy/tls-permission", params: { domain: business.custom_domain }
    expect(response).to have_http_status(:not_found)
  end

  def create_business(custom_domain:, custom_domain_enabled:)
    owner = User.create!(
      email_address: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    owner.create_business!(
      name: "Aura Centro",
      slug: "aura-#{SecureRandom.hex(3)}",
      contact_phone: "+54 9 11 2222-2222",
      custom_domain: custom_domain,
      custom_domain_enabled: custom_domain_enabled,
      onboarding_completed_at: Time.current
    )
  end

  def browser_headers
    { "HTTP_USER_AGENT" => "Mozilla/5.0 Chrome/120.0.0.0 Safari/537.36" }
  end
end
