require "rails_helper"

RSpec.describe "Public websites", type: :request do
  before { host! "localhost" }

  it "keeps the current reservation-link homepage as the default mode" do
    business = create_business(public_custom_html: '<section class="ht-section ht-about"><h2>Solo web completa</h2></section>')
    service = create_service(business, category: "Depilación", slug: "depilacion-laser")
    service.service_category.cover_image.attach(category_image_upload)

    get public_business_path(business.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("data-controller=\"public-services\"")
    expect(response.body).to include("/#{business.slug}/depilacion/depilacion-laser")
    expect(response.body).not_to include("category-cover.png")
    expect(response.body).not_to include("Solo web completa")

    get public_category_path(business.slug, service.service_category.slug), headers: browser_headers

    expect(response).to redirect_to(root_path)
  end

  it "renders a complete website with category pages and a CSS override" do
    business = create_business(
      public_site_mode: "full_website",
      public_custom_html: <<~HTML
        <style>.ht-about { background: rgb(242, 237, 227); }</style>
        <section class="ht-section ht-about" id="equipo">
          <div class="ht-section__inner">
            <img class="ht-about__image" src="https://images.example.com/centro.jpg" alt="El centro">
            <div><p class="ht-section__eyebrow">Quiénes somos</p><h2>Atención personalizada</h2><p>Un espacio pensado para vos.</p><a href="javascript:alert('no')">Enlace inseguro</a></div>
          </div>
          <script>window.customSectionScriptShouldNotRun = true</script>
        </section>
      HTML
    )
    laser = create_service(business, category: "Depilación", slug: "depilacion-laser")
    create_service(business, name: "Limpieza facial", category: "Facial", slug: "limpieza-facial")
    laser.service_category.cover_image.attach(category_image_upload)

    get public_business_path(business.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Nuestros servicios")
    expect(response.body).to include("/#{business.slug}/depilacion")
    expect(response.body).not_to include("data-controller=\"public-services\"")

    document = Nokogiri::HTML(response.body)
    custom_section = document.at_css("[data-public-custom-sections] #equipo")
    expect(custom_section).to be_present
    expect(custom_section.text).to include("Atención personalizada")
    expect(custom_section.at_css("img")["src"]).to eq("https://images.example.com/centro.jpg")
    expect(custom_section.at_css("a")["href"]).to be_nil
    expect(response.body).not_to include("<script>window.customSectionScriptShouldNotRun")
    expect(response.body).to include(".ht-about { background: rgb(242, 237, 227); }")
    category_image = document.at_css("#servicios img[alt='Depilación']")
    expect(category_image).to be_present
    expect(category_image["src"]).to include("category-cover.png")

    get public_category_path(business.slug, laser.service_category.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Depilación")
    expect(response.body).to include("Depilación láser")
    expect(response.body).to include("/#{business.slug}/depilacion/depilacion-laser")

    get public_category_service_path(business.slug, laser.service_category.slug, laser.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar fecha y hora")
  end

  it "shows professionals in a complete website only when the booking-page option is enabled" do
    business = create_business(public_site_mode: "full_website", public_show_professionals: true)
    create_service(business, category: "Depilación", slug: "depilacion-laser")
    business.employee_memberships.create!(
      name: "Gloria Principal",
      first_name: "Gloria",
      last_name: "Principal",
      email_address: "gloria-#{SecureRandom.hex(4)}@example.com",
      status: "active",
      can_receive_appointments: true
    )

    get public_business_path(business.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Quién te atiende")
    expect(response.body).not_to include("Gloria Principal")

    business.update!(preferences: business.preferences.merge("public_booking_show_team_members" => true))

    get public_business_path(business.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Quién te atiende")
    expect(response.body).not_to include("Gloria Principal")
  end

  it "does not expose the former service URL" do
    business = create_business
    service = create_service(business, category: "Depilación", slug: "depilacion-laser")

    get "/#{business.slug}/#{service.slug}", headers: browser_headers

    expect(response).to redirect_to(root_path)
  end

  it "uses the HTML block as the complete editable content of a website" do
    business = create_business(
      public_site_mode: "full_website",
      public_custom_html: '<section class="ht-section"><h1>Una web diseñada a medida</h1><p>Contenido editorial.</p></section>'
    )
    create_service(business, category: "Depilación", slug: "depilacion-laser")

    get public_business_path(business.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Una web diseñada a medida")
    expect(response.body).to include("Contenido editorial")
    expect(response.body).to include("data-dog-grooming-categories")
    expect(response.body).not_to include("data-full-website-hero-actions")
  end

  it "replaces the categories slot with the real category section in its declared position" do
    business = create_business(
      public_site_mode: "full_website",
      public_custom_html: <<~HTML
        <header><nav><a href="#inicio">{{business_name}}</a></nav></header>
        <section id="antes-del-menu"><h1>Antes del menú</h1></section>
        <video autoplay muted loop playsinline src="https://videos.example.com/portada.mp4"></video>
        <div data-dog-grooming-slot="categories"></div>
        <footer id="despues-del-menu"><h2>Después del menú</h2></footer>
      HTML
    )
    create_service(business, category: "Depilación", slug: "depilacion-laser")

    get public_business_path(business.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)

    document = Nokogiri::HTML(response.body)
    body_html = document.at_css("main[data-full-website]").to_html
    before_index = body_html.index("antes-del-menu")
    categories_index = body_html.index("data-dog-grooming-categories")
    after_index = body_html.index("despues-del-menu")

    expect(before_index).to be < categories_index
    expect(categories_index).to be < after_index
    expect(document.css("[data-dog-grooming-categories]").size).to eq(1)
    expect(response.body).not_to include("data-dog-grooming-slot")
    expect(document.at_css("header nav a")&.text).to eq(business.name)
    expect(document.at_css("video")&.[]("src")).to eq("https://videos.example.com/portada.mp4")
    expect(document.at_css("video")&.key?("autoplay")).to be(true)
  end

  it "renders the category HTML with dynamic values and only that category's services" do
    business = create_business(
      public_site_mode: "full_website",
      public_category_custom_html: <<~HTML
        <section id="categoria-portada">
          <p>{{business_name}}</p>
          <h1>{{category_name_uppercase}}</h1>
          <p>{{category_description}}</p>
          <a href="{{home_url}}">Volver al inicio</a>
        </section>
        <section id="tratamientos"><div data-dog-grooming-slot="services"></div></section>
        <footer id="categoria-pie">{{business_phone}}</footer>
      HTML
    )
    laser = create_service(business, category: "Depilación", slug: "depilacion-laser")
    facial = create_service(business, name: "Limpieza facial", category: "Facial", slug: "limpieza-facial")
    laser.service_category.update!(description: "Tratamientos para una piel más suave.")

    get public_category_path(business.slug, laser.service_category.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)

    document = Nokogiri::HTML(response.body)
    category_header = document.at_css("#categoria-portada")
    main_html = document.at_css("main.ht-full-website").to_html

    expect(category_header.text).to include(business.name)
    expect(category_header.text).to include("DEPILACIÓN")
    expect(category_header.text).to include("Tratamientos para una piel más suave.")
    expect(category_header.at_css("a")["href"]).to eq("/#{business.slug}")
    expect(document.at_css("#categoria-pie").text).to include(business.contact_phone)
    expect(document.css("[data-dog-grooming-category-services] .ht-service-card").map(&:text).join).to include(laser.name)
    expect(document.css("[data-dog-grooming-category-services] .ht-service-card").map(&:text).join).not_to include(facial.name)
    expect(main_html.index("categoria-portada")).to be < main_html.index("data-dog-grooming-category-services")
    expect(main_html.index("data-dog-grooming-category-services")).to be < main_html.index("categoria-pie")
    expect(response.body).not_to include("{{category_name_uppercase}}")
    expect(response.body).not_to include("data-dog-grooming-slot")
  end

  private
    def create_business(**attributes)
      owner = User.create!(
        email_address: "web-owner-#{SecureRandom.hex(4)}@example.com",
        password: "password123"
      )
      owner.create_business!(
        {
          name: "Centro Aura",
          slug: "aura-#{SecureRandom.hex(3)}",
          contact_phone: "+54 9 11 2222-2222",
          onboarding_completed_at: Time.current
        }.merge(attributes)
      )
    end

    def create_service(business, name: "Depilación láser", category:, slug:)
      business.services.create!(
        name: name,
        slug: slug,
        category: category,
        description: "Tratamiento profesional.",
        duration_minutes: 30,
        price_cents: 15_000,
        active: true,
        public_visible: true,
        visibility_mode: "public"
      )
    end

    def category_image_upload
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/service-gallery.png").to_s,
        "image/png",
        original_filename: "category-cover.png"
      )
    end

    def browser_headers
      { "HTTP_USER_AGENT" => "Mozilla/5.0 Chrome/120.0.0.0 Safari/537.36" }
    end
end
