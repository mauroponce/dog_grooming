require "rails_helper"

RSpec.describe "Admin customer profiles", type: :request do
  before { host! "localhost" }

  it "returns recent customers with paginated autocomplete for the calendar" do
    user, business = create_admin_with_business
    now = Time.current
    CustomerProfile.insert_all!(21.times.map do |index|
      phone = "+54 9 11 8#{index.to_s.rjust(7, '0')}"
      {
        business_id: business.id,
        name: "Cliente #{index.to_s.rjust(2, '0')}",
        phone: phone,
        normalized_phone: PhoneNumber.normalize(phone),
        customer_portal_token: CustomerProfile.unique_customer_portal_token,
        customer_portal_short_token: CustomerProfile.unique_customer_portal_short_token,
        created_at: now + index.seconds,
        updated_at: now + index.seconds
      }
    end)

    sign_in(user)
    get autocomplete_admin_customer_profiles_path(format: :json), params: { page: 1 }, headers: browser_headers

    payload = response.parsed_body
    expect(response).to have_http_status(:ok)
    expect(payload.fetch("results").length).to eq(20)
    expect(payload.fetch("has_more")).to eq(true)

    get autocomplete_admin_customer_profiles_path(format: :json), params: { q: "Cliente 03", page: 1 }, headers: browser_headers
    expect(response.parsed_body.fetch("results").map { |customer| customer.fetch("name") }).to eq([ "Cliente 03" ])

    customer = business.customer_profiles.find_by!(name: "Cliente 03")
    get panel_admin_customer_profile_path(customer, format: :json), headers: browser_headers
    panel = response.parsed_body
    expect(response).to have_http_status(:ok)
    expect(panel.dig("customer", "name")).to eq("Cliente 03")
    expect(panel.dig("customer", "appointmentsCount")).to eq(0)
    expect(panel.dig("customer", "totalSales")).to eq(0)
    expect(panel.dig("customer", "canceledCount")).to eq(0)
    expect(panel.dig("customer", "noShowCount")).to eq(0)
    expect(panel.fetch("appointments")).to eq([])
  end

  it "renders the dark customer list with existing customers" do
    user, business = create_admin_with_business
    pedro = CustomerProfile.create!(
      business: business,
      first_name: "Pedro",
      last_name: "Porro",
      phone: "+54 9 11 1111-1111",
      email: "pedro@example.com"
    )
    CustomerProfile.create!(
      business: business,
      first_name: "Jane",
      last_name: "Doe",
      phone: "+54 9 11 2222-2222",
      email: "jane@example.com"
    )

    sign_in(user)
    get admin_customer_profiles_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Lista de clientes")
    expect(response.body).to include("Pedro Porro")
    expect(response.body).to include("jane@example.com")
    expect(response.body).to include("Añadir")
    expect(response.body).to include("wa.me")
    expect(response.body).to include("customerProfileDrawerBackdrop")
    expect(response.body).not_to include("El link privado permite ver y gestionar sus turnos")

    document = Nokogiri::HTML(response.body)
    header_labels = document.css(".customers-table-head p").map { |node| node.text.strip }
    row = document.at_css("#customer_#{pedro.id}")
    expect(header_labels).to eq([ "Cliente", "Próximo / Último turno", "Contacto", "Estado del turno", "Valor", "Acciones" ])
    expect(row["data-customer-row-url"]).to eq(edit_admin_customer_profile_path(pedro))
    expect(row["data-customer-profile-drawer-url"]).to be_nil
    expect(row.at_css(".customers-action-button").text).to include("Acciones")
    expect(row.at_css(".customers-actions-menu").text).to include("Editar", "Eliminar permanentemente")
    expect(row.text.squish).not_to include("WhatsApp:")
  end

  it "sorts customers by creation date and non-canceled appointments while preserving search and pagination" do
    user, business = create_admin_with_business
    service = business.services.create!(name: "Servicio de prueba", slug: "servicio-de-prueba", duration_minutes: 30)
    newest = business.customer_profiles.create!(name: "Cliente nuevo", phone: "+54 9 11 5555-0001")
    oldest = business.customer_profiles.create!(name: "Cliente antiguo", phone: "+54 9 11 5555-0002")
    middle = business.customer_profiles.create!(name: "Cliente intermedio", phone: "+54 9 11 5555-0003")
    newest.update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)
    oldest.update_columns(created_at: 4.days.ago, updated_at: 4.days.ago)
    middle.update_columns(created_at: 3.days.ago, updated_at: 3.days.ago)

    2.times do |index|
      business.appointments.create!(
        service: service,
        customer_profile: oldest,
        customer_name: oldest.name,
        customer_phone: oldest.phone,
        starts_at: (index + 1).days.ago.change(hour: 10 + index),
        ends_at: (index + 1).days.ago.change(hour: 10 + index, min: 30),
        status: :completed
      )
    end
    business.appointments.create!(
      service: service,
      customer_profile: middle,
      customer_name: middle.name,
      customer_phone: middle.phone,
      starts_at: 3.hours.ago,
      ends_at: 2.hours.ago,
      status: :confirmed
    )

    sign_in(user)

    get admin_customer_profiles_path, headers: browser_headers
    document = Nokogiri::HTML(response.body)
    expect(document.css(".customers-row").map { |row| row["id"] }).to eq([ "customer_#{newest.id}", "customer_#{middle.id}", "customer_#{oldest.id}" ])
    expect(document.css(".customers-sort-input option").map(&:text)).to eq([
      "Más nuevos",
      "Más antiguos",
      "Más turnos",
      "Menos turnos"
    ])
    expect(document.at_css(".customers-sort-direction")).to be_nil
    expect(document.at_css("form.customers-toolbar-form")["data-turbo-frame"]).to eq("customers_results")
    expect(document.at_css(".customers-sort-input")["data-action"]).to include("auto-submit#submit")
    expect(document.at_css("form.customers-toolbar-form")["data-customers-results-loader-target"]).to eq("form")
    expect(document.css(".customers-sort-option").map { |option| option.text.strip }).to eq([
      "Más nuevos",
      "Más antiguos",
      "Más turnos",
      "Menos turnos"
    ])
    expect(document.at_css(".customers-results-loader")).to be_present
    expect(document.at_css(".customers-results-loader-ring")).to be_present

    get admin_customer_profiles_path, params: { sort: "created_at_asc" }, headers: browser_headers
    document = Nokogiri::HTML(response.body)
    expect(document.css(".customers-row").map { |row| row["id"] }).to eq([ "customer_#{oldest.id}", "customer_#{middle.id}", "customer_#{newest.id}" ])

    get admin_customer_profiles_path, params: { sort: "completed_appointments_desc", q: "Cliente" }, headers: browser_headers
    document = Nokogiri::HTML(response.body)
    expect(document.css(".customers-row").map { |row| row["id"] }).to eq([ "customer_#{oldest.id}", "customer_#{middle.id}", "customer_#{newest.id}" ])
    expect(document.at_css(".customers-sort-input option[selected]")["value"]).to eq("completed_appointments_desc")

    get admin_customer_profiles_path, params: { sort: "completed_appointments_asc" }, headers: browser_headers
    document = Nokogiri::HTML(response.body)
    expect(document.css(".customers-row").map { |row| row["id"] }).to eq([ "customer_#{newest.id}", "customer_#{middle.id}", "customer_#{oldest.id}" ])

    21.times do |index|
      business.customer_profiles.create!(name: "Paginado #{index}", phone: "+54 9 11 5556-#{index.to_s.rjust(4, '0')}")
    end
    get admin_customer_profiles_path, params: { sort: "completed_appointments_asc", q: "Paginado" }, headers: browser_headers
    document = Nokogiri::HTML(response.body)
    pagination_urls = document.css(".customers-pagination a").map { |link| link["href"] }.join
    expect(pagination_urls).to include("sort=completed_appointments_asc")
    expect(pagination_urls).to include("q=Paginado")
  end

  it "searches customers in the database before pagination is applied" do
    user, business = create_admin_with_business
    old_time = 2.days.ago
    target = business.customer_profiles.create!(
      name: "Zulema Busqueda Profunda",
      phone: "+54 9 11 3333-0000",
      email: "zulema@example.com",
      created_at: old_time,
      updated_at: old_time
    )

    CustomerProfile.insert_all!(30.times.map do |index|
      phone = "+54 9 11 7#{index.to_s.rjust(7, '0')}"
      {
        business_id: business.id,
        name: "Cliente Nuevo #{index.to_s.rjust(2, '0')}",
        phone: phone,
        normalized_phone: PhoneNumber.normalize(phone),
        customer_portal_token: CustomerProfile.unique_customer_portal_token,
        customer_portal_short_token: CustomerProfile.unique_customer_portal_short_token,
        created_at: Time.current + index.seconds,
        updated_at: Time.current + index.seconds
      }
    end)

    sign_in(user)
    get admin_customer_profiles_path, headers: browser_headers
    expect(response.body).not_to include(target.name)

    get admin_customer_profiles_path, params: { q: "Zulema" }, headers: browser_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(target.name)
  end

  it "renders the new customer form with birth date and gender fields" do
    user, = create_admin_with_business

    sign_in(user)
    get new_admin_customer_profile_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Añadir cliente")
    expect(response.body).to include("Fecha de nacimiento")
    expect(response.body).to include("Masculino")
    expect(response.body).to include("Femenino")
  end

  it "renders the edit customer form with existing values" do
    user, business = create_admin_with_business
    customer = business.customer_profiles.create!(
      first_name: "Ada",
      last_name: "Lovelace",
      phone: "+54 9 11 3333-3333",
      email: "ada@example.com",
      birth_date: Date.new(1990, 12, 10),
      gender: "femenino"
    )

    sign_in(user)
    calendar_return_path = admin_calendar_path(date: "2026-08-04", appointment_id: 123)
    get edit_admin_customer_profile_path(customer), params: { return_to: calendar_return_path }, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ficha del responsable")
    expect(response.body).to include("Datos personales")
    expect(response.body).to include("Mascotas")
    expect(response.body).to include("Turnos")
    expect(response.body).to include("Notas")
    expect(response.body).to include("Fotos")
    expect(response.body).to include("Cerrar")
    expect(response.body).to include("Ada")
    expect(response.body).to include("Lovelace")
    expect(response.body).to include("Guardar cambios")
    expect(Nokogiri::HTML(response.body).at_css(".admin-shell-app")).to be_nil
    document = Nokogiri::HTML(response.body)
    birth_date_input = document.at_css("#customer_profile_birth_date")
    expect(birth_date_input["value"]).to eq("10/12/1990")
    expect(birth_date_input["maxlength"]).to eq("10")
    expect(birth_date_input["data-customer-birth-date-target"]).to eq("input")
    expect(birth_date_input["data-action"]).to include("input->customer-birth-date#format")
    expect(document.at_css("form[data-controller~='customer-birth-date']")).to be_present
    expect(document.at_css("[data-customer-birth-date-target='error']")).to be_present
    whatsapp_link = document.at_css(".customer-profile-editor__whatsapp-link")
    expect(whatsapp_link.text).to eq("Abrir en WhatsApp")
    expect(whatsapp_link["href"]).to eq(PhoneNumber.whatsapp_link(customer.phone))
    turnos_link = document.at_css('[data-customer-editor-tabs-tab-value="appointments"]')
    expect(turnos_link.name).to eq("a")
    expect(turnos_link["href"]).to eq("#{edit_admin_customer_profile_path(customer)}#turnos")
    close_link = document.at_css(".customer-profile-editor__button--secondary")
    expect(close_link["href"]).to eq(calendar_return_path)
    expect(Nokogiri::HTML(response.body).at_css('input[name="return_to"]')["value"]).to eq(calendar_return_path)
  end

  it "redirects the retired customer detail URL to the editor" do
    user, business = create_admin_with_business
    customer = business.customer_profiles.create!(name: "Ada Lovelace", phone: "+54 9 11 3333-3333")

    sign_in(user)
    get admin_customer_profile_path(customer), headers: browser_headers

    expect(response).to redirect_to(edit_admin_customer_profile_path(customer))
  end

  it "renders appointments without a date badge and with Spanish dates" do
    user, business = create_admin_with_business
    user.update!(name: "Julian Alvarez")
    customer = business.customer_profiles.create!(name: "Ada Lovelace", phone: "+54 9 11 3333-3333")
    newer_service = business.services.create!(name: "Laminado de cejas", slug: "laminado-de-cejas", duration_minutes: 45)
    business.appointments.create!(
      customer_profile: customer,
      customer_name: customer.name,
      customer_phone: customer.phone,
      service: newer_service,
      starts_at: Time.zone.local(2026, 8, 5, 11),
      ends_at: Time.zone.local(2026, 8, 5, 11, 45),
      status: :confirmed
    )
    service = business.services.create!(name: "Diseño y perfilado de cejas", slug: "diseno-de-cejas", duration_minutes: 30)
    appointment = business.appointments.create!(
      customer_profile: customer,
      customer_name: customer.name,
      customer_phone: customer.phone,
      service: service,
      starts_at: Time.zone.local(2026, 8, 4, 11),
      ends_at: Time.zone.local(2026, 8, 4, 11, 30),
      status: :confirmed
    )
    appointment.cancel!(by: user, reason: "El cliente no puede asistir.")

    sign_in(user)
    get edit_admin_customer_profile_path(customer), params: { section: "appointments" }, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    rows = document.css(".customer-profile-editor__appointment")
    row = document.css(".customer-profile-editor__appointment").find { |item| item.text.include?("Diseño y perfilado de cejas") }
    expect(rows.first.text.squish).to include("Laminado de cejas", "05/08/2026")
    expect(row.text.squish).to include("04/08/2026")
    expect(row.text.squish).to include("Cancelado por Julian Alvarez")
    expect(row.text).not_to include("August")
    expect(row.at_css(".customer-profile-editor__appointment-date")).to be_nil
    portal_link = document.at_css(".customer-profile-editor__portal-url")
    expect(portal_link.text).to eq(customer.customer_portal_url)
    expect(portal_link["href"]).to eq(customer.customer_portal_url)
    expect(portal_link["target"]).to eq("_blank")
    portal_copy = document.at_css(".customer-profile-editor__portal-copy")
    expect(portal_copy["data-action"]).to include("copy-text#copy")
    expect(portal_copy["title"]).to eq("Copiar")
  end

  it "uses consistent appointment badges and opens the shared detail panel from the history" do
    now = Time.current
      user, business = create_admin_with_business
      customer = business.customer_profiles.create!(name: "Ada Lovelace", phone: "+54 9 11 3333-3333")
      service = business.services.create!(name: "Depilación con cera", slug: "depilacion-cera-history", duration_minutes: 30)
      create_appointment = lambda do |starts_at:, status:|
        business.appointments.create!(
          customer_profile: customer,
          customer_name: customer.name,
          customer_phone: customer.phone,
          service: service,
          starts_at: starts_at,
          ends_at: starts_at + 30.minutes,
          status: status
        )
      end
      confirmed = create_appointment.call(starts_at: now + 1.day, status: :confirmed)
      review = create_appointment.call(starts_at: now + 2.days, status: :pending_deposit_review)
      canceled = create_appointment.call(starts_at: now + 3.days, status: :canceled)
      completed = create_appointment.call(starts_at: now - 2.hours, status: :confirmed)

      sign_in(user)
      get edit_admin_customer_profile_path(customer), params: { section: "appointments" }, headers: browser_headers

      document = Nokogiri::HTML(response.body)
      rows = document.css(".customer-profile-editor__appointment")
      details_path_for = ->(appointment) { admin_appointment_details_path(appointment, format: :json, context: "customer_profile") }
      row_for = ->(appointment) { rows.find { |row| row["data-customer-appointments-details-url"] == details_path_for.call(appointment) } }

      expect(row_for.call(confirmed).text).to include("Confirmado")
      expect(row_for.call(confirmed)["data-customer-appointments-variant-param"]).to eq("customer-profile")
      expect(row_for.call(confirmed).at_css(".customer-profile-editor__appointment-status")["class"]).to include("customer-status-green")
      expect(row_for.call(review).text).to include("Seña pendiente de aprobación")
      expect(row_for.call(review).at_css(".customer-profile-editor__appointment-status")["class"]).to include("customer-status-amber")
      expect(row_for.call(canceled).text).to include("Cancelado")
      expect(row_for.call(canceled).at_css(".customer-profile-editor__appointment-status")["class"]).to include("customer-status-red")
      expect(row_for.call(completed).text).to include("Finalizado")
      expect(row_for.call(completed).at_css(".customer-profile-editor__appointment-status")["class"]).to include("customer-status-violet")
      expect(document.at_css("[data-controller~='customer-appointments']")).to be_present
      expect(document.at_css("[data-customer-appointments-target='drawer']")).to be_present
  end

  it "paginates the customer appointment history with a Turbo frame" do
    user, business = create_admin_with_business
    customer = business.customer_profiles.create!(name: "Ada Lovelace", phone: "+54 9 11 3333-3333")
    service = business.services.create!(name: "Limpieza facial", slug: "limpieza-facial-history", duration_minutes: 45)

    21.times do |index|
      starts_at = Time.zone.local(2026, 8, 1, 10).advance(days: index)
      business.appointments.create!(
        customer_profile: customer,
        customer_name: customer.name,
        customer_phone: customer.phone,
        service: service,
        starts_at: starts_at,
        ends_at: starts_at + 45.minutes,
        status: :confirmed
      )
    end

    sign_in(user)
    get edit_admin_customer_profile_path(customer), params: { section: "appointments" }, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    next_link = document.at_css('turbo-frame#customer_appointment_history a[rel="next"]')
    rows = document.css("turbo-frame#customer_appointment_history .customer-profile-editor__appointment")

    expect(rows.size).to eq(20)
    expect(rows.first.text.squish).to include("21/08/2026")
    expect(next_link["data-turbo-frame"]).to eq("customer_appointment_history")
    expect(next_link["href"]).to include("page=2")

    get edit_admin_customer_profile_path(customer), params: { section: "appointments", page: 2 }, headers: browser_headers

    page_two = Nokogiri::HTML(response.body)
    page_two_rows = page_two.css("turbo-frame#customer_appointment_history .customer-profile-editor__appointment")
    expect(page_two_rows.size).to eq(1)
    expect(page_two_rows.first.text.squish).to include("01/08/2026")
  end

  it "updates customer notes from the standalone editor and preserves the selected section" do
    user, business = create_admin_with_business
    customer = business.customer_profiles.create!(name: "Ada Lovelace", phone: "+54 9 11 3333-3333")

    sign_in(user)
    patch admin_customer_profile_path(customer), params: {
      section: "notes",
      customer_profile: {
        first_name: "Ada",
        last_name: "Lovelace",
        phone: "+54 9 11 4444-4444",
        email: "ada@example.com",
        internal_notes: "Piel sensible. Confirmar tolerancia antes de aplicar exfoliantes."
      }
    }, headers: browser_headers

    expect(response).to redirect_to(edit_admin_customer_profile_path(customer, section: "notes"))
    expect(customer.reload).to have_attributes(phone: "+54 9 11 4444-4444", internal_notes: "Piel sensible. Confirmar tolerancia antes de aplicar exfoliantes.")
  end

  it "uploads and removes private customer photos from the editor" do
    user, business = create_admin_with_business
    customer = business.customer_profiles.create!(name: "Ada Lovelace", phone: "+54 9 11 3333-3333")

    sign_in(user)
    patch admin_customer_profile_path(customer), params: {
      section: "photos",
      customer_profile: {
        customer_photos: [ fixture_file_upload("service-gallery.png", "image/png") ]
      }
    }, headers: browser_headers

    expect(response).to redirect_to(edit_admin_customer_profile_path(customer, section: "photos"))
    photo = customer.reload.customer_photos.attachments.sole
    expect(customer.customer_photos).to be_attached

    get edit_admin_customer_profile_path(customer), params: { section: "photos" }, headers: browser_headers
    expect(response.body).to include("Galería privada")
    expect(response.body).to include(photo.filename.to_s)

    expect {
      delete destroy_photo_admin_customer_profile_path(customer, attachment_id: photo.id), headers: browser_headers
    }.to change { customer.reload.customer_photos.attachments.count }.from(1).to(0)

    expect(response).to redirect_to(edit_admin_customer_profile_path(customer, section: "photos"))
  end

  it "creates a customer from the new customer page" do
    user, business = create_admin_with_business

    sign_in(user)

    before_count = CustomerProfile.count
    post admin_customer_profiles_path, params: {
      source: "new_customer_page",
      customer_profile: {
        first_name: "Ada",
        last_name: "Lovelace",
        phone: "+54 9 11 3333-3333",
        email: "ada@example.com",
        birth_day: "10",
        birth_month: "12",
        birth_year: "1990",
        gender: "femenino",
        pets_attributes: {
          "0" => {
            name: "Coco",
            breed: "Caniche",
            size: "small",
            sex: "male",
            notes: "Cepillado suave en patas."
          }
        }
      }
    }, headers: browser_headers

    customer = business.customer_profiles.order(:created_at).last
    expect(response).to have_http_status(:redirect)
    expect(CustomerProfile.count).to eq(before_count + 1)
    expect(response).to redirect_to(edit_admin_customer_profile_path(customer))
    expect(customer).to have_attributes(
      first_name: "Ada",
      last_name: "Lovelace",
      name: "Ada Lovelace",
      email: "ada@example.com",
      birth_date: Date.new(1990, 12, 10),
      gender: "femenino"
    )
    expect(customer.pets.sole).to have_attributes(
      name: "Coco",
      breed: "Caniche",
      size: "small",
      sex: "male",
      business: business
    )
  end

  it "soft deletes a customer and excludes their appointments from the calendar" do
    user, business = create_admin_with_business
    customer = business.customer_profiles.create!(
      first_name: "Grace",
      last_name: "Hopper",
      phone: "+54 9 11 4444-4444",
      email: "grace@example.com"
    )
    service = business.services.create!(name: "Consulta Grace", slug: "consulta-grace", duration_minutes: 30)
    starts_at = 2.days.from_now.change(hour: 10, min: 0)
    appointment = business.appointments.create!(
      customer_profile: customer,
      customer_name: customer.name,
      customer_phone: customer.phone,
      service: service,
      starts_at: starts_at,
      ends_at: starts_at + 30.minutes,
      status: :confirmed
    )

    sign_in(user)

    expect {
      delete admin_customer_profile_path(customer), headers: browser_headers
    }.not_to change { CustomerProfile.unscoped.where(business: business).count }

    expect(response).to redirect_to(admin_customer_profiles_path)
    expect(CustomerProfile.unscoped.find(customer.id).deleted_at).to be_present
    expect(business.customer_profiles.where(id: customer.id)).to be_empty
    expect(Appointment.unscoped.where(id: appointment.id)).to exist
    expect(business.appointments.where(id: appointment.id)).to be_empty

    get admin_customer_profiles_path, headers: browser_headers
    expect(response.body).not_to include("Grace Hopper")

    get edit_admin_customer_profile_path(customer), headers: browser_headers
    expect(response).to have_http_status(:not_found)

    get admin_calendar_path(date: starts_at.to_date.iso8601), headers: browser_headers
    calendar_appointments = JSON.parse(response.body.match(/let appointments = (.+?);/)[1])
    expect(calendar_appointments).not_to include(include("id" => appointment.short_uuid))
  end

  it "requires WhatsApp when creating a customer" do
    user, = create_admin_with_business

    sign_in(user)

    expect {
      post admin_customer_profiles_path, params: {
        source: "new_customer_page",
        customer_profile: {
          first_name: "Ada",
          last_name: "Lovelace",
          phone: "",
          email: "ada@example.com"
        }
      }, headers: browser_headers
    }.not_to change(CustomerProfile, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Añadir cliente")
  end

  it "does not expose the removed general data route" do
    user, = create_admin_with_business

    sign_in(user)
    get "/admin/datos-generales", headers: browser_headers

    expect(response).to redirect_to("/")
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

  def create_admin_with_business
    user = User.create!(
      email_address: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )
    business = Business.create!(
      owner: user,
      name: "Casa De Mangos",
      slug: "casa-de-mangos-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 1234-5678",
      onboarding_completed_at: Time.current
    )

    [ user, business ]
  end
end
