require "rails_helper"

RSpec.describe "Super admin businesses", type: :request do
  before { host! "localhost" }

  it "allows super admins to view the businesses dashboard" do
    user = create_user(role: :super_admin, email_prefix: "super")

    sign_in(user)
    get super_admin_businesses_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Negocios registrados")
    expect(response.body).to include("Nueva cuenta")
    expect(response.body).not_to include("Conexiones externas")
    expect(response.body).to include("Tutoriales")
    expect(response.body).not_to include("Panel de control Cita.pet")
    expect(response.body).not_to include("Tabla compacta para operar cuentas, trials, setup y soporte")
  end

  it "deletes a business that has a team member" do
    super_admin = create_user(role: :super_admin, email_prefix: "super-delete")
    owner = create_user(role: :admin, email_prefix: "owner-delete")
    business = Business.create!(
      owner: owner,
      name: "Delete Center",
      slug: "delete-center-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )
    business.employee_memberships.create!(
      name: "Profesional Demo",
      first_name: "Profesional",
      last_name: "Demo",
      email_address: "professional-delete-#{SecureRandom.hex(4)}@example.com",
      status: "active"
    )
    sign_in(super_admin)

    expect {
      delete super_admin_business_path(business), headers: browser_headers
    }.to change(Business, :count).by(-1)

    expect(response).to redirect_to(super_admin_businesses_path)
    expect(EmployeeMembership.where(business_id: business.id)).not_to exist
  end

  it "renders compact business rows with public slug links and an actions menu" do
    super_admin = create_user(role: :super_admin, email_prefix: "super-list")
    owner = create_user(role: :admin, email_prefix: "owner-list")
    business = Business.create!(
      owner: owner,
      name: "Public Link Center",
      slug: "public-link-center-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )

    with_public_host_defaults do
      sign_in(super_admin)
      get super_admin_businesses_path, headers: browser_headers
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("http://localhost:3003/#{business.slug}")
    expect(response.body).to include("Entrar")
    expect(response.body).to include("Editar")
    expect(response.body).to include("Eliminar")
    expect(response.body).to include("¿Seguro que querés eliminar Public Link Center?")
    expect(response.body).not_to include("Loguearse")
    expect(response.body).not_to include(">Uso 30d</th>")
    expect(response.body).not_to include(">Suscripción</th>")
    expect(response.body).not_to include(">Sistema</th>")
    expect(response.body).not_to include(">Setup</th>")
  end

  it "allows super admins to open the new business form without Google OAuth copy" do
    user = create_user(role: :super_admin, email_prefix: "super-new")

    sign_in(user)
    get new_super_admin_business_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Datos del negocio")
      expect(response.body).not_to include("Categorías y servicios")
    expect(response.body).to include("Nombre del centro")
      expect(response.body).to include("Nombre del dueño")
    expect(response.body).to include("Facturación Cita.pet activa")
      expect(response.body).to include("Teléfono del negocio")
    expect(document.at_css("#business_account_owner_email")["required"]).to eq("required")
    expect(document.at_css("#business_account_contact_phone")["required"]).to eq("required")
    expect(response.body).to include("Instagram")
    expect(response.body).not_to include("Acerca de")
    expect(response.body).to include("Dirección del negocio")
    expect(response.body).to include("Horarios de atención")
    expect(response.body).not_to include("entra directo con Google")
    expect(response.body).not_to include("catalog")
    expect(response.body).not_to include("data-super-admin-categories-payload")
  end

  it "creates a business account with Instagram and a phone without sending a welcome email" do
    user = create_user(role: :super_admin, email_prefix: "super-create")
    owner_email = "owner-welcome-#{SecureRandom.hex(4)}@example.com"
    slug = "owner-welcome-#{SecureRandom.hex(4)}"
    instagram_url = "https://instagram.com/aurawelcome"
    expect(StaffAccessMailer).not_to receive(:welcome)

    sign_in(user)
    post super_admin_businesses_path,
      params: {
          business_account: {
            business_name: "Aura Welcome",
            owner_name: "Mauro Ponce",
            owner_email: owner_email,
          contact_phone: "+54 9 11 5555-1234",
          instagram_url: instagram_url,
          slogan: "Belleza facial con agenda simple",
          address: "Av. Corrientes 1234, CABA",
          address_details: "Piso 3, Depto B",
          latitude: "-34.6037",
          longitude: "-58.3816",
          province: "CABA",
          city: "CABA",
          slug: slug,
          availability_rules: availability_rules_params(
            "1" => { active: "1", start_time: "10:00", end_time: "19:00", break_start_time: "13:00", break_end_time: "15:00" },
            "6" => { active: "0", start_time: "10:00", end_time: "19:00", break_start_time: "", break_end_time: "" }
          )
        }
      },
      headers: browser_headers

      business = Business.find_by!(slug: slug)
      owner_membership = business.employee_memberships.find_by!(user: business.owner)
      monday_rule = business.availability_rules.find_by!(weekday: 1)
      saturday_rule = business.availability_rules.find_by!(weekday: 6)
    expect(business.owner.password_digest).to be_nil
      expect(business.owner.name).to eq("Mauro Ponce")
      expect(owner_membership.name).to eq("Mauro Ponce")
      expect(owner_membership.first_name).to eq("Mauro")
      expect(owner_membership.last_name).to eq("Ponce")
      expect(business.contact_phone).to eq("+54 9 11 5555-1234")
    expect(business.instagram_url).to eq("https://www.instagram.com/aurawelcome")
    expect(business.slogan).to eq("Belleza facial con agenda simple")
    expect(business.address).to eq("Av. Corrientes 1234, CABA")
    expect(business.address_details).to eq("Piso 3, Depto B")
    expect(business.public_location).to include("Av. Corrientes 1234, Piso 3, Depto B, CABA")
    expect(business.latitude).to eq(-34.6037)
    expect(business.longitude).to eq(-58.3816)
    expect(business.province).to eq("CABA")
    expect(business.city).to eq("CABA")
    expect(business.branches.find_by!(name: "Principal").address_details).to eq("Piso 3, Depto B")
    expect(monday_rule).to be_active
    expect(monday_rule.start_time.strftime("%H:%M")).to eq("10:00")
    expect(monday_rule.break_start_time.strftime("%H:%M")).to eq("13:00")
    expect(monday_rule.break_end_time.strftime("%H:%M")).to eq("15:00")
    expect(monday_rule.end_time.strftime("%H:%M")).to eq("19:00")
    expect(saturday_rule).not_to be_active
    expect(business.service_categories).to be_empty
    expect(business.services).to be_empty
    expect(response).to redirect_to(edit_super_admin_business_path(business))
  end

  it "requires the owner's email and the business phone when creating an account" do
    user = create_user(role: :super_admin, email_prefix: "super-required-contact")

    sign_in(user)

    expect {
      post super_admin_businesses_path,
        params: {
          business_account: {
            business_name: "Centro sin email",
            owner_name: "Dueña del centro",
            owner_email: "",
            contact_phone: "+54 9 11 5555-1234"
          }
        },
        headers: browser_headers
    }.not_to change(Business, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Completá el email de acceso del dueño.")

    expect {
      post super_admin_businesses_path,
        params: {
          business_account: {
            business_name: "Centro sin teléfono",
            owner_name: "Dueña del centro",
            owner_email: "contacto-obligatorio-#{SecureRandom.hex(4)}@example.com",
            contact_phone: "   "
          }
        },
        headers: browser_headers
    }.not_to change(Business, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Completá el teléfono del negocio.")
  end

  it "creates a business account with an uploaded logo" do
    user = create_user(role: :super_admin, email_prefix: "super-create-images")
    owner_email = "owner-images-#{SecureRandom.hex(4)}@example.com"
    slug = "owner-images-#{SecureRandom.hex(4)}"
    sign_in(user)
    post super_admin_businesses_path,
      params: {
          business_account: {
            business_name: "Imagen Center",
            owner_name: "Imagen Owner",
            owner_email: owner_email,
          contact_phone: "+54 9 11 5555-1234",
          instagram_url: "",
          address: "Av. Corrientes 1234, CABA",
          latitude: "-34.6037",
          longitude: "-58.3816",
          province: "CABA",
          city: "CABA",
          slug: slug,
          logo: business_image_upload("logo.png")
        }
      },
      headers: browser_headers

    business = Business.find_by!(slug: slug)
    expect(response).to redirect_to(edit_super_admin_business_path(business))
    expect(business.logo).to be_attached
    expect(business.logo.blob.key).to include("#{slug}/imagenes/logos/")
  end

  it "creates a free business without a billing subscription when billing is disabled" do
    user = create_user(role: :super_admin, email_prefix: "super-free")
    owner_email = "owner-free-#{SecureRandom.hex(4)}@example.com"
    slug = "owner-free-#{SecureRandom.hex(4)}"
    sign_in(user)
    post super_admin_businesses_path,
      params: {
        business_account: {
          business_name: "Centro Gratis",
          owner_name: "Dueña Gratis",
          owner_email: owner_email,
          billing_enabled: "0",
          contact_phone: "+54 9 11 5555-1234",
          instagram_url: "",
          address: "Av. Corrientes 1234, CABA",
          latitude: "-34.6037",
          longitude: "-58.3816",
          province: "CABA",
          city: "CABA",
          slug: slug
        }
      },
      headers: browser_headers

    business = Business.find_by!(slug: slug)
    expect(response).to redirect_to(edit_super_admin_business_path(business))
    expect(business.billing_enabled).to be(false)
    expect(business.subscription).to be_nil
    expect(business.access_active?).to be(true)
  end

  it "allows super admins to edit a business with the same account fields" do
    super_admin = create_user(role: :super_admin, email_prefix: "super-edit")
    owner = create_user(role: :admin, email_prefix: "owner-edit")
    business = Business.create!(
      owner: owner,
      name: "Original Center",
      slug: "original-center-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      instagram_url: "https://instagram.com/original",
      onboarding_completed_at: Time.current
    )

    sign_in(super_admin)
    get edit_super_admin_business_path(business), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Editar negocio")
    expect(response.body).to include("Original Center")
    expect(response.body).not_to include("Categorías y servicios")
    expect(response.body).to include("Instagram")
    expect(response.body).to include("Slogan")
    expect(response.body).to include("Teléfono del negocio")

    new_owner_email = "edited-owner-#{SecureRandom.hex(4)}@example.com"
    patch super_admin_business_path(business),
      params: {
          business_account: {
            business_name: "Edited Center",
          owner_name: "Editada Dueña",
            owner_email: new_owner_email,
          billing_enabled: "0",
          contact_phone: "+54 9 11 5555-4321",
          instagram_url: "https://instagram.com/edited",
          slogan: "Turnos claros, belleza real",
          address: "Av. Santa Fe 456, CABA",
          address_details: "Torre Norte, 7A",
          latitude: "-34.5951",
          longitude: "-58.3974",
          province: "CABA",
          city: "CABA",
          slug: "edited-center-#{SecureRandom.hex(4)}",
          availability_rules: availability_rules_params(
            "2" => { active: "1", start_time: "09:30", end_time: "18:30", break_start_time: "", break_end_time: "" }
          )
        }
      },
      headers: browser_headers

    business.reload
    tuesday_rule = business.availability_rules.find_by!(weekday: 2)
    expect(response).to redirect_to(edit_super_admin_business_path(business))
    expect(business.name).to eq("Edited Center")
    expect(business.billing_enabled).to be(false)
    expect(business.contact_phone).to eq("+54 9 11 5555-4321")
    expect(business.instagram_url).to eq("https://www.instagram.com/edited")
    expect(business.slogan).to eq("Turnos claros, belleza real")
    expect(business.address).to eq("Av. Santa Fe 456, CABA")
    expect(business.address_details).to eq("Torre Norte, 7A")
    expect(business.latitude).to eq(-34.5951)
    expect(business.longitude).to eq(-58.3974)
    expect(business.province).to eq("CABA")
    expect(business.city).to eq("CABA")
    expect(tuesday_rule).to be_active
    expect(tuesday_rule.start_time.strftime("%H:%M")).to eq("09:30")
    expect(tuesday_rule.end_time.strftime("%H:%M")).to eq("18:30")
    expect(tuesday_rule.break_start_time).to be_nil
    expect(tuesday_rule.break_end_time).to be_nil
    expect(owner.reload.email_address).to eq(new_owner_email)
    expect(owner.name).to eq("Editada Dueña")
    expect(business.employee_memberships.find_by!(user: owner).name).to eq("Editada Dueña")
    expect(business.services).to be_empty
    expect(business.branches.find_by!(name: "Principal").address_details).to eq("Torre Norte, 7A")
  end

  it "does not modify existing categories or services from Super Admin" do
    super_admin = create_user(role: :super_admin, email_prefix: "super-rename")
    owner = create_user(role: :admin, email_prefix: "owner-rename")
    business = Business.create!(
      owner: owner,
      name: "Rename Center",
      slug: "rename-center-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )
    category = business.service_categories.create!(
      name: "Uñas",
      slug: "unas",
      primary_category: true,
      active: true,
      sort_order: 0
    )
    service = business.services.create!(
      service_category: category,
      name: "Esmaltado",
      slug: "esmaltado",
      category: category.name,
      description: "Esmaltado clásico",
      duration_minutes: 30,
      price_cents: 20_000,
      deposit_amount_cents: 0,
      active: true,
      public_visible: true,
      visibility_mode: "public",
      sort_order: 0
    )
    categories_payload = [
      {
        id: category.id,
        name: "Nails",
        primary: true,
        services: [
          {
            id: service.id,
            name: "Esmaltado premium",
            description: "Esmaltado premium",
            duration_minutes: 45,
            price_cents: 25_000,
            active: true,
            public_visible: true
          }
        ]
      }
    ].to_json

    sign_in(super_admin)
    patch super_admin_business_path(business),
      params: {
        business_account: {
          business_name: business.name,
          owner_name: owner.name.presence || "Dueña",
          owner_email: owner.email_address,
          contact_phone: business.contact_phone,
          instagram_url: business.instagram_url,
          address: business.address,
          latitude: business.latitude,
          longitude: business.longitude,
          province: business.province,
          city: business.city,
          slug: business.slug,
          categories_payload: categories_payload
        }
      },
      headers: browser_headers

    expect(response).to redirect_to(edit_super_admin_business_path(business))
    expect(business.service_categories.count).to eq(1)
    expect(business.services.count).to eq(1)
    expect(category.reload.name).to eq("Uñas")
    expect(category.slug).to eq("unas")
    expect(category).to be_primary_category
    expect(service.reload.name).to eq("Esmaltado")
    expect(service.slug).to eq("esmaltado")
    expect(service.service_category).to eq(category)
  end

  it "redirects regular admins away from super admin" do
    user = create_user(role: :admin, email_prefix: "regular")
    Business.create!(
      owner: user,
      name: "Regular Center",
      slug: "regular-center-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )

    sign_in(user)
    get super_admin_businesses_path, headers: browser_headers

    expect(response).to redirect_to(root_path)
  end

  it "extends the trial and synchronizes a pending invoice without changing approved payments" do
    super_admin = create_user(role: :super_admin, email_prefix: "super-trial")
    owner = create_user(role: :admin, email_prefix: "owner-trial")
    business = Business.create!(owner: owner, name: "Trial Center", slug: "trial-center-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-5555", onboarding_completed_at: Time.current)
    original_due_on = business.subscription.next_due_on
    pending_invoice = Billing::EnsureCurrentInvoice.call(business: business, force: true)
    paid_invoice = business.subscription.subscription_invoices.create!(
      business: business,
      period_start: 2.months.ago.to_date,
      period_end: 1.month.ago.to_date,
      billing_period_months: 1,
      amount_cents: business.monthly_amount_cents,
      due_on: 2.months.ago.to_date,
      reference_code: "PAID-#{SecureRandom.hex(4).upcase}",
      status: "paid",
      paid_at: 2.months.ago
    )
    paid_attributes = paid_invoice.attributes.slice("due_on", "period_start", "period_end", "status", "paid_at")
    sign_in(super_admin)

    patch extend_trial_super_admin_business_path(business), headers: browser_headers

    new_due_on = original_due_on + 7.days
    expect(response).to redirect_to(super_admin_businesses_path(business_id: business.id))
    expect(business.reload.trial_ends_at.to_date).to eq(new_due_on)
    expect(business.subscription.reload).to have_attributes(
      status: "trialing",
      trial_ends_on: new_due_on,
      next_due_on: new_due_on,
      grace_ends_on: new_due_on + 3.days
    )
    expect(pending_invoice.reload).to have_attributes(due_on: new_due_on, period_start: new_due_on, status: "open")
    expect(paid_invoice.reload.attributes.slice(*paid_attributes.keys)).to eq(paid_attributes)
  end

  it "extends grace from the effective date and prevents automatic suspension" do
    super_admin = create_user(role: :super_admin, email_prefix: "super-grace")
    owner = create_user(role: :admin, email_prefix: "owner-grace")
    business = Business.create!(owner: owner, name: "Grace Center", slug: "grace-center-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-5555", onboarding_completed_at: Time.current)
    invoice = Billing::EnsureCurrentInvoice.call(business: business, force: true)
    invoice.update!(due_on: 5.days.ago.to_date, period_start: 5.days.ago.to_date, period_end: 25.days.from_now.to_date, status: "overdue")
    business.subscription.update!(status: "suspended", next_due_on: invoice.due_on, grace_ends_on: 2.days.ago.to_date, suspended_at: Time.current)
    sign_in(super_admin)

    patch extend_grace_super_admin_business_path(business), headers: browser_headers
    Billing::DailyProcessor.new(today: Time.zone.today).call

    expect(response).to redirect_to(super_admin_businesses_path(business_id: business.id))
    expect(business.subscription.reload.grace_ends_on).to eq(7.days.from_now.to_date)
    expect(business.subscription).to be_overdue
    expect(business).to be_access_active
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

  def with_public_host_defaults
    previous_host = ENV.delete("APP_HOST")
    previous_protocol = ENV.delete("APP_PROTOCOL")
    yield
  ensure
    ENV["APP_HOST"] = previous_host if previous_host
    ENV["APP_PROTOCOL"] = previous_protocol if previous_protocol
  end

  def business_image_upload(filename)
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/service-gallery.png").to_s,
      "image/png",
      original_filename: filename
    )
  end

  def availability_rules_params(overrides = {})
    Business::DAYS.to_h.keys.index_with do |weekday|
      {
        active: weekday.in?([ 1, 2, 3, 4, 5 ]) ? "1" : "0",
        start_time: "10:00",
        end_time: "19:00",
        break_start_time: "",
        break_end_time: ""
      }.merge(overrides.fetch(weekday.to_s, {}))
    end
  end

  def create_service_catalog_category
    ServiceCatalogCategory.create!(
      key: "test_category_#{SecureRandom.hex(4)}",
      name: "Estética",
      business_industry: "aesthetics"
    )
  end

  def create_service_catalog_item(category, name:, price:)
    category.service_catalog_items.create!(
      name: name,
      service_category: category.name,
      description: "#{name} para tests",
      duration_minutes: 30,
      price_cents: price.to_i * 100,
      sort_order: 1,
      active: true
    )
  end
end
