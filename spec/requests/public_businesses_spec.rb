require "rails_helper"
require "nokogiri"
require "uri"

RSpec.describe "Public businesses", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before { host! "localhost" }

  it "renders the public service categories without destacados" do
    business = create_business
    business.update!(
      slogan: "Belleza simple, turnos claros",
      address: "Manuel Castro 1001",
      city: "Lomas de Zamora",
      province: "Buenos Aires"
    )
    business.services.create!(
      name: "Consulta inicial",
      category: "Peluquería",
      description: "Evaluación inicial para definir el servicio.",
      duration_minutes: 30,
      price_cents: 0,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )

    get public_business_path(business.slug), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    sticky_nav = document.at_css("[data-controller='public-section-nav']")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ver mis turnos")
    expect(response.body).to include("Reserva en línea segura")
    expect(response.body).to include("Belleza simple, turnos claros")
    expect(response.body).to include("Confirmación inmediata")
    expect(document.at_css("[data-public-business-title]").text).to include(business.name)
    expect(document.at_css("[data-public-business-title] + p").text).to include("Belleza simple, turnos claros")
    expect(document.at_css("a[href*='google.com/maps/dir']")).to be_present
    expect(sticky_nav).to be_present
    expect(sticky_nav["class"]).not_to include("lg:hidden")
    expect(sticky_nav.css("a[href='#services-section']").text).to include("Servicios")
    expect(sticky_nav.css("a[href='#team-section']")).to be_empty
    expect(sticky_nav.css("a[href='#about-section']")).to be_empty
    expect(sticky_nav.css("a[href='#hours-section']").text).to include("Horarios")
    expect(document.at_css("#hours-section")).to be_present
    expect(response.body).not_to include("Acerca de")
    expect(response.body).to include("Servicios")
    expect(response.body).to include("Peluquería")
    expect(response.body).to include("Consulta inicial")
    expect(response.body).to include("Consultar")
    expect(document.at_css("a[href='https://dog-grooming.example.com']").text).to include("Dog Grooming")
    expect(response.body).not_to include("Destacados")
    expect(response.body).not_to include("Reseñas")
  end

  it "renders the current opening status in the public banner" do
    business = create_business

    travel_to Time.zone.local(2026, 8, 3, 10, 0, 0) do
      get public_business_path(business.slug), headers: browser_headers
    end

    document = Nokogiri::HTML(response.body)
    status = document.at_css("[data-public-hours-status]")

    expect(response).to have_http_status(:ok)
    expect(status.text.squish).to include("Abierto ahora - hasta las 18:00")
    expect(status.at_css("[data-public-hours-state]")["class"]).to include("text-emerald-600")

    travel_to Time.zone.local(2026, 8, 3, 20, 0, 0) do
      get public_business_path(business.slug), headers: browser_headers
    end

    document = Nokogiri::HTML(response.body)
    status = document.at_css("[data-public-hours-status]")

    expect(response).to have_http_status(:ok)
    expect(status.text.squish).to include("Cerrado - abre martes a las 09:00")
    expect(status.at_css("[data-public-hours-state]")["class"]).to include("text-red-500")
    expect(status.at_css("[data-public-hours-detail]")["class"]).to include("font-bold")
  end

  it "renders a category service link as booking with the service preselected" do
    business = create_business
    service = business.services.create!(
      name: "Esmaltado",
      slug: "esmaltado",
      category: "Uñas",
      description: "Esmaltado tradicional con terminación prolija.",
      duration_minutes: 30,
      price_cents: 15_000,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )

    get public_category_service_path(business.slug, service.service_category.slug, service.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar fecha y hora")
    expect(response.body).not_to include("Seleccionar profesional")
    expect(response.body).to include("Esmaltado")
    expect(response).not_to redirect_to(root_path)
    expect(response).not_to redirect_to(new_session_path)
  end

  it "preserves the selected category when closing a service detail modal" do
    business = create_business
    service = business.services.create!(
      name: "Lifting de pestañas",
      slug: "lifting-de-pestanas",
      category: "Pestañas",
      duration_minutes: 45,
      price_cents: 18_000,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )
    business.services.create!(
      name: "Corte",
      slug: "corte",
      category: "Peluquería",
      duration_minutes: 30,
      price_cents: 12_000,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )

    get public_business_path(business.slug, category: "Pestañas", service_detail: service.slug), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    services_section = document.at_css("[data-controller~='public-services']")
    modal = document.at_css("[data-public-service-detail-modal]")
    close_link = modal.at_css("a[aria-label='Cerrar']")
    close_query = Rack::Utils.parse_nested_query(URI.parse(close_link["href"]).query)

    expect(response).to have_http_status(:ok)
    expect(services_section["data-public-services-initial-category-value"]).to eq("Pestañas")
    expect(modal["class"]).to include("fixed", "inset-0", "z-[2147483646]")
    expect(modal.parent["class"]).to include("public-page-shell")
    expect(modal.parent["class"]).not_to include("z-10")
    expect(close_query["category"]).to eq("Pestañas")

    get close_link["href"], headers: browser_headers

    closed_document = Nokogiri::HTML(response.body)
    closed_services_section = closed_document.at_css("[data-controller~='public-services']")
    selected_tab = closed_document.css("[data-public-services-target='tab']").find do |tab|
      tab["data-category"] == "Pestañas"
    end

    expect(response).to have_http_status(:ok)
    expect(closed_services_section["data-public-services-initial-category-value"]).to eq("Pestañas")
    expect(selected_tab["class"]).to include("bg-zinc-950")
  end

  it "renders a visible close cross in the public service image gallery" do
    business = create_business
    service = business.services.create!(
      name: "Baño y corte",
      slug: "bano-y-corte",
      category: "Baño y secado",
      duration_minutes: 45,
      price_cents: 18_000,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )

    File.open(Rails.root.join("spec/fixtures/files/service-gallery.png")) do |file|
      service.service_images.attach(io: file, filename: "service-gallery.png", content_type: "image/png")
    end

    get public_business_path(business.slug, category: "Baño y secado", service_detail: service.slug), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    gallery_modal = document.at_css("[data-public-service-gallery-target='modal']")
    gallery_close_button = gallery_modal.at_css("button[aria-label='Cerrar galería']")

    expect(response).to have_http_status(:ok)
    expect(gallery_close_button).to be_present
    expect(gallery_close_button.text.strip).to eq("×")
    expect(gallery_close_button["data-action"]).to eq("public-service-gallery#close")
    expect(gallery_close_button["class"]).to include("right-4")
    expect(gallery_close_button["class"]).to include("top-5")
  end

  it "renders a category service link even when the optional description is blank" do
    business = create_business
    service = business.services.create!(
      name: "Esmaltado",
      slug: "esmaltado",
      category: "Uñas",
      duration_minutes: 30,
      price_cents: 15_000,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )

    get public_category_service_path(business.slug, service.service_category.slug, service.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar fecha y hora")
    expect(response.body).not_to include("Seleccionar profesional")
    expect(response.body).to include("Esmaltado")
    expect(response).not_to redirect_to(root_path)
    expect(response).not_to redirect_to(new_session_path)
  end

  it "renders link-only services by direct short URL without listing them on the public business page" do
    business = create_business
    service = business.services.create!(
      name: "Nails",
      slug: "nails",
      category: "Uñas",
      duration_minutes: 30,
      price_cents: 15_000,
      active: true,
      public_visible: true,
      visibility_mode: "link_only"
    )

    get public_business_path(business.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Nails")

    get public_category_service_path(business.slug, service.service_category.slug, service.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar fecha y hora")
    expect(response.body).not_to include("Seleccionar profesional")
    expect(response.body).to include("Nails")
    expect(response).not_to redirect_to(root_path)
    expect(response).not_to redirect_to(new_session_path)
  end

  it "renders team profiles below services and opens a professional services modal" do
    business = create_business
    business.update!(preferences: business.preferences.merge("public_booking_show_team_members" => true))
    manicure = business.services.create!(
      name: "Manicura",
      slug: "manicura",
      category: "Uñas",
      duration_minutes: 45,
      price_cents: 18_000,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )
    haircut = business.services.create!(
      name: "Corte de cabello",
      slug: "corte-de-cabello",
      category: "Peluquería",
      duration_minutes: 60,
      price_cents: 19_500,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )
    other_service = business.services.create!(
      name: "Depilación",
      slug: "depilacion",
      category: "Estética",
      duration_minutes: 30,
      price_cents: 12_000,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )
    professional = business.employee_memberships.create!(
      first_name: "Jésica",
      last_name: "López",
      email_address: "jesica-#{SecureRandom.hex(4)}@example.com",
      status: "active",
      specialty: "Peluquera",
      calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first
    )
    other_professional = business.employee_memberships.create!(
      first_name: "Erik",
      last_name: "Torres",
      email_address: "erik-#{SecureRandom.hex(4)}@example.com",
      status: "active",
      specialty: "Barbero",
      calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.second
    )
    haircut.employee_memberships << professional
    other_service.employee_memberships << other_professional

    get public_business_path(business.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Equipo")
    expect(response.body).to include("Jésica López")
    expect(response.body).to include("Peluquera")
    expect(response.body).to include("professional_id=#{professional.id}")

    get public_business_path(business.slug, professional_id: professional.id), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    modal = document.at_css("[data-public-professional-modal]")
    dialog = document.at_css("[data-public-professional-dialog]")
    reserve_link = modal.at_css("a[href*='employee_membership_id=#{professional.id}'][href*='professional_mode=single']")

    expect(response).to have_http_status(:ok)
    expect(modal).to be_present
    expect(dialog).to be_present
    expect(dialog["class"]).to include("max-w-[720px]")
    expect(modal.text).to include("Jésica López")
    expect(modal.text).to include("Peluquera")
    expect(modal.text).to include("Corte de cabello")
    expect(modal.text).to include("Manicura")
    expect(modal.text).not_to include("Depilación")
    expect(reserve_link).to be_present
    expect(reserve_link["href"]).to include("/#{business.slug}/peluqueria/corte-de-cabello")
  end

  it "renders about, map and opening hours below the team section" do
    business = create_business
    business.update!(preferences: business.preferences.merge("public_booking_show_team_members" => true))
    business.update!(
      address: "Manuel Castro 1001",
      city: "Banfield",
      province: "Provincia de Buenos Aires",
      latitude: -34.74325,
      longitude: -58.39568
    )
    business.availability_rules.find_by!(weekday: 2).update!(start_time: "10:00", end_time: "19:00")
    business.services.create!(
      name: "Esmaltado",
      slug: "esmaltado",
      category: "Uñas",
      duration_minutes: 30,
      price_cents: 20_000,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )
    business.employee_memberships.create!(
      first_name: "Jennifer",
      last_name: "López",
      email_address: "jennifer-#{SecureRandom.hex(4)}@example.com",
      status: "active",
      specialty: "Estética y belleza",
      calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first
    )

    get public_business_path(business.slug), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    hours_section = document.at_css("section#hours-section")
    hours_grid = hours_section.at_css(".public-hours-map-grid")
    map_frame = hours_grid.at_css("iframe")
    mobile_address = hours_grid.at_css(".public-hours-section p.lg\\:hidden")
    desktop_address = hours_grid.at_css("p.lg\\:block")

    expect(response).to have_http_status(:ok)
    expect(document.at_css("section#team-section + section#hours-section")).to be_present
    expect(hours_grid).to be_present
    expect(map_frame["src"]).to include("openstreetmap.org/export/embed.html")
    expect(map_frame["src"]).to include("-58.39918%2C-34.74675")
    expect(mobile_address.text).to include("Manuel Castro 1001")
    expect(mobile_address.text).to include("Cómo llegar")
    expect(mobile_address.at_css("a")["href"]).to include("google.com/maps/dir")
    expect(desktop_address.text).to include("Manuel Castro 1001")
    expect(desktop_address.text).to include("Cómo llegar")
    expect(desktop_address.at_css("a")["href"]).to include("google.com/maps/dir")
    expect(hours_section.text).to include("Horarios")
    expect(hours_section.text).to include("martes")
    expect(hours_section.text).to include("10:00 - 19:00")
    expect(response.body).to include("border-radius: 9999px;")
  end

  it "omits location and map content when the business has no location configured" do
    business = create_business

    get public_business_path(business.slug), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    hours_section = document.at_css("section#hours-section")

    expect(response).to have_http_status(:ok)
    expect(hours_section.at_css(".public-hours-map-grid")).to be_nil
    expect(hours_section.at_css("iframe")).to be_nil
    expect(hours_section.text).not_to include("Ubicación a confirmar")
    expect(document.at_css("[data-public-business-title]").parent.text).not_to include("Ubicación a confirmar")
  end

  def create_business
    owner = User.create!(
      email_address: "public-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )

    Business.create!(
      owner: owner,
      name: "Public Test Center",
      slug: "public-test-center-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )
  end

  def browser_headers
    {
      "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36",
      "HTTP_USER_AGENT" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"
    }
  end
end
