require "rails_helper"
require "nokogiri"

RSpec.describe "Admin services", type: :request do
  before { host! "localhost" }

  it "searches services only by their name" do
    user, business = create_admin_with_business
    matching_service = create_service(business, name: "Masajes descontracturantes")
    description_match = create_service(business, name: "Depilación con cera")
    description_match.update!(description: "Una opción que dura más tiempo.")

    sign_in(user)
    get admin_services_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    matching_row = document.css("[data-services-service-row]").find { |row| row.at_css(".service-row-title").text.squish == matching_service.name }
    description_row = document.css("[data-services-service-row]").find { |row| row.at_css(".service-row-title").text.squish == description_match.name }

    expect(response).to have_http_status(:ok)
    expect(document.at_css('input[data-services-search-input]')["placeholder"]).to eq("Buscar por nombre de servicio")
    expect(matching_row["data-services-search"]).to eq(matching_service.name)
    expect(description_row["data-services-search"]).to eq(description_match.name)
    expect(Services::InboxQuery.new(business:, params: { q: "mas" }).services).to include(matching_service)
    expect(Services::InboxQuery.new(business:, params: { q: "mas" }).services).not_to include(description_match)
  end

  it "renders the new service form with price and an unchecked deposit checkbox" do
    user, business = create_admin_with_business
    employee = create_employee(business, first_name: "Mauro", last_name: "Ponce")
    payment_account = business.payment_accounts.create!(name: "BBVA principal", details: "Alias: NAVAJA.CLUB", primary_account: true)

    sign_in(user)
    get new_admin_service_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    service_form = document.at_css("form.service-editor-form")
    name_field = document.at_css('input[name="service[name]"]')
    deposit_checkbox = document.at_css('input[type="checkbox"][name="service[deposit_required]"]')
    deposit_amount = document.at_css('input[name="service[deposit_amount]"]')
    availability_start = document.at_css('input[name="service[availability_starts_on]"]')
    availability_end = document.at_css('input[name="service[availability_ends_on]"]')
    upload_zone = document.at_css(".service-upload-zone")
    image_input = document.at_css('input[type="file"][name="service[service_images][]"]')
    description_field = document.at_css('textarea[name="service[description]"]')
    category_field = document.at_css('select[name="service[service_category_id]"]')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Nuevo servicio")
    expect(response.body).to include("service-editor-shell")
    expect(response.body).to include("Volver al listado")
    expect(response.body).to include("Información básica")
    expect(response.body).to include("Miembros del equipo")
    expect(response.body).to include("Imágenes")
    expect(response.body).to include("Horarios")
    expect(response.body).not_to include("service-editor-tab-chevron")
    expect(response.body).not_to include("¿Querés copiar este horario a todos los días disponibles?")
    expect(response.body).to include("Mauro Ponce")
    expect(response.body).to include("Buscar profesional...")
    expect(response.body).to include("Seleccionar todos")
    expect(response.body).to include("Recomendación")
    expect(response.body).to include("Precio")
    expect(response.body).not_to include("Cómo se calcula el precio")
    expect(response.body).not_to include("Por tamaño de mascota")
    expect(response.body).to include("Requiere seña")
    expect(response.body).not_to include("Cómo cobrar este servicio")
    expect(response.body).not_to include("Usar configuración del negocio")
    expect(response.body).not_to include("Mercado Pago - pago total")
    expect(response.body).to include("Valor de seña")
    expect(response.body).not_to include("Este importe se cobra para reservar")
    expect(response.body).not_to include("Cuenta para comprobante manual")
    expect(response.body).not_to include(payment_account.display_name)
    expect(response.body).to include("Arrastra y suelta tus imágenes aquí")
    expect(response.body).to include("Guardar imágenes")
    expect(response.body).not_to include("Vista rápida antes de guardar el servicio.")
    expect(response.body).not_to include("Recursos")
    expect(service_form["enctype"]).to eq("multipart/form-data")
    expect(name_field).to be_present
    expect(name_field.ancestors.any? { |node| node["class"].to_s.include?("service-field-full") }).to eq(true)
    price_input = document.at_css('input[name="service[price]"]')
    expect(price_input).to be_present
    expect(price_input["type"]).to eq("text")
    expect(price_input["inputmode"]).to eq("numeric")
    expect(category_field["class"]).to include("service-custom-select-input")
    expect(category_field["data-native-select"]).to eq("true")
    expect(category_field["data-custom-select-target"]).to eq("input")
    category_dropdown = category_field.ancestors.find { |node| node["data-controller"].to_s.split.include?("custom-select") }
    expect(category_dropdown.at_css(".service-custom-select-trigger")).to be_present
    expect(category_dropdown.css(".service-custom-select-option").map { |option| option.text.squish }).to eq(category_field.css("option").map { |option| option.text.squish })
    expect(document.at_css('select[name="service[payment_strategy]"]')).to be_nil
    expect(description_field).to be_present
    expect(document.at_css('[data-controller~="service-description-ai"]')).to be_nil
    expect(deposit_checkbox).to be_present
    expect(deposit_checkbox["checked"]).to be_nil
    expect(deposit_checkbox["data-action"]).to eq("service-deposit#toggle")
    expect(deposit_checkbox.ancestors.any? { |node| node["class"].to_s.include?("service-toggle-control") }).to eq(true)
    expect(deposit_amount).to be_present
    expect(deposit_amount["type"]).to eq("text")
    expect(deposit_amount["inputmode"]).to eq("numeric")
    expect(availability_start["type"]).to eq("text")
    expect(availability_start["placeholder"]).to eq("dd/mm/aaaa")
    expect(availability_end["type"]).to eq("text")
    expect(availability_end["placeholder"]).to eq("dd/mm/aaaa")
    expect(document.at_css('[data-service-deposit-target="amount"]').attribute("hidden")).to be_present
    expect(document.at_css('select[name="service[payment_account_id]"]')).to be_nil
    expect(document.at_css('input[type="checkbox"][name="service[employee_membership_ids][]"][value="' + employee.id.to_s + '"]')).to be_present
    expect(upload_zone["data-action"]).to include("drop->service-image-upload#drop")
    expect(image_input).to be_present
    expect(image_input["data-action"]).to eq("change->service-image-upload#sync")
    expect(image_input["data-service-image-upload-target"]).to eq("input")
    expect(document.at_css('input[type="checkbox"][name="service[limit_availability_by_date]"]')["checked"]).to be_nil
    expect(document.at_css('input[type="checkbox"][name="service[use_advanced_availability]"]')["checked"]).to be_nil
    expect(document.at_css("[data-service-availability-target='dateFields']").attribute("hidden")).to be_present
    expect(document.at_css("[data-service-availability-target='weeklyFields']").attribute("hidden")).to be_present
    expect(document.css('select[name^="service_availability_rules"]').map { |field| field["class"] }.uniq).to eq([ "service-custom-select-input" ])
  end

  it "never renders manual receipt accounts in the service editor" do
    user, business = create_admin_with_business
    business.payment_accounts.create!(name: "BBVA principal", details: "Alias: NAVAJA.CLUB", primary_account: true)
    business.payment_accounts.create!(name: "Cuenta secundaria", details: "Alias: NAVAJA.SEC")

    sign_in(user)
    get new_admin_service_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Cuenta para comprobante manual")
    expect(document.at_css('select[name="service[payment_account_id]"]')).to be_nil
  end

  it "explains that Mercado Pago confirms deposit bookings automatically when it is the only connected method" do
    user, business = create_admin_with_business
    business.update!(preferences: business.preferences.merge("enabled_payment_methods" => [ "mercado_pago" ]))
    business.create_mercado_pago_connection!(
      access_token: "mp-token",
      refresh_token: "mp-refresh",
      mercado_pago_user_id: "123",
      connected_at: Time.current
    )
    service = create_service(business, name: "Corte clásico")
    service.update!(deposit_required: true, deposit_amount_cents: 3_000_00)

    sign_in(user)
    get edit_admin_service_path(service), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    deposit_panel = document.at_css('[data-service-deposit-target="amount"]')

    expect(response).to have_http_status(:ok)
    expect(deposit_panel["hidden"]).to be_nil
    expect(deposit_panel.text.squish).to include("Se cobrará la seña a través de Mercado Pago y el turno quedará confirmado automáticamente.")
    expect(deposit_panel.text).not_to include("Podés pedir una seña")
    expect(deposit_panel.text).not_to include("comprobante de transferencia")
    expect(document.at_css('select[name="service[payment_account_id]"]')).to be_nil
  end

  it "explains that Mercado Pago must be connected before collecting a deposit" do
    user, business = create_admin_with_business
    service = create_service(business, name: "Corte clásico")
    service.update!(deposit_required: true, deposit_amount_cents: 3_000_00)

    sign_in(user)
    get edit_admin_service_path(service), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    deposit_panel = document.at_css('[data-service-deposit-target="amount"]')

    expect(response).to have_http_status(:ok)
    expect(deposit_panel["hidden"]).to be_nil
    expect(deposit_panel.text.squish).to include("Para recibir señas y confirmar estos turnos, conectá Mercado Pago en Configuración.")
    expect(deposit_panel.text).not_to include("comprobante de transferencia")
    expect(document.at_css('select[name="service[payment_account_id]"]')).to be_nil
  end

  it "creates a service with price, deposit value, team members and service images from the new service page" do
    user, business = create_admin_with_business
    category = ServiceCategory.find_or_create_for!(business: business, name: "Barbería", primary_category: true)
    employee = create_employee(business, first_name: "Pepe", last_name: "Chatruc")
    payment_account = business.payment_accounts.create!(name: "Cuenta secundaria", details: "Alias: NAVAJA.SEC", primary_account: true)

    sign_in(user)

    expect {
      post admin_services_path, params: {
        minimal: "1",
        service: {
          name: "Corte clásico",
          service_category_id: category.id,
          price: "12000",
          deposit_required: "1",
          deposit_amount: "4000",
          payment_account_id: payment_account.id,
          description: "Corte a tijera o máquina.",
          all_employee_memberships: "0",
          employee_membership_ids: [ employee.id.to_s ],
          service_images: [ service_image_upload ]
        }
      }, headers: browser_headers
    }.to change(Service, :count).by(1)

    service = business.services.order(:created_at).last
    expect(response).to redirect_to(admin_services_path(service_category_id: category.id, service_id: service.id))
    expect(service.price_cents).to eq(1_200_000)
    expect(service.deposit_amount_cents).to eq(400_000)
    expect(service.deposit_required?).to be(true)
    expect(service.payment_account).to eq(payment_account)
    expect(service.employee_membership_ids).to eq([ employee.id ])
    expect(service.service_images.attached?).to be(true)
    service_image_blob = service.service_images.attachments.first.blob
    expect(service_image_blob.service_name).to eq("service_images")
    expect(service_image_blob.key).to include("/imagenes/servicios/galeria/")

    follow_redirect!
    expect(response.body.scan("Servicio creado para completar después.").size).to eq(1)
    expect(response.body).to include(%(data-controller="flash-toast"))
    expect(response.body).to include(%(aria-label="Cerrar mensaje"))
  end

  it "publishes an active service when the reservation-page visibility toggle is enabled" do
    user, business = create_admin_with_business
    service = create_service(business, name: "Lifting de pestañas")
    service.update_columns(active: false, visibility_mode: "hidden", public_visible: true)

    sign_in(user)
    patch admin_service_path(service), params: {
      service: {
        name: service.name,
        service_category_id: service.service_category_id,
        duration_minutes: service.duration_minutes,
        price: "12000",
        description: service.description,
        active: "0",
        visibility_mode: "hidden",
        public_visible: "1"
      }
    }, headers: browser_headers

    expect(response).to redirect_to(edit_admin_service_path(service))
    expect(service.reload).to have_attributes(active: true, visibility_mode: "public", public_visible: true)
    expect(service).to be_public

    get public_business_path(business.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Lifting de pestañas")

    get new_public_booking_path(business.slug, step: "services"), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Lifting de pestañas")
  end

  it "keeps a duplicated service private until it is explicitly made visible" do
    user, business = create_admin_with_business
    service = create_service(business, name: "Lifting de pestañas")

    sign_in(user)
    expect {
      post duplicate_admin_service_path(service), headers: browser_headers
    }.to change(Service, :count).by(1)

    copy = business.services.order(:created_at).last

    expect(response).to redirect_to(admin_services_path(service_id: copy.id))
    expect(copy).to have_attributes(active: false, visibility_mode: "hidden", public_visible: false)
  end

  it "shows a clear error when payment is enabled without a deposit value" do
    user, business = create_admin_with_business
    category = ServiceCategory.find_or_create_for!(business: business, name: "Barbería", primary_category: true)

    sign_in(user)

    expect {
      post admin_services_path, params: {
        minimal: "1",
        service: {
          name: "Perfilado de barba",
          service_category_id: category.id,
          price: "9000",
          deposit_required: "1",
          deposit_amount: "",
          description: "Definición de contornos y rebaje."
        }
      }, headers: browser_headers
    }.not_to change(Service, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Valor de seña debe estar definido para pedir pago de seña")
  end

  it "links service rows in the services index to the edit page" do
    user, business = create_admin_with_business
    service = create_service(business, name: "Corte clásico")
    service.update!(deposit_required: true, deposit_amount_cents: 2_000_00)

    sign_in(user)
    get admin_services_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    row = document.at_css("a.service-row-link")

    expect(response).to have_http_status(:ok)
    expect(row).to be_present
    expect(row["href"]).to eq(edit_admin_service_path(service))
    expect(document.at_css(".service-row").css(".service-row-badge").map { |badge| badge.text.squish }).to eq([ "Activo", "Seña: $2.000" ])
  end

  it "shows a gray no-deposit badge for services that do not require a deposit" do
    user, business = create_admin_with_business
    service = create_service(business, name: "Depilación Láser")

    sign_in(user)
    get admin_services_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    row = document.css("[data-services-service-row]").find { |service_row| service_row.at_css(".service-row-title").text.squish == service.name }
    badges = row.css(".service-row-badge")

    expect(response).to have_http_status(:ok)
    expect(badges.map { |badge| badge.text.squish }).to eq([ "Activo", "No requiere seña" ])
    expect(badges.last["class"]).to include("is-no-deposit")
  end

  it "renders category heading edit and delete controls without a category description field" do
    user, business = create_admin_with_business
    service = create_service(business, name: "Decoración")
    category = service.service_category
    category.update!(name: "Nails", description: "Descripción interna de categoría")

    sign_in(user)
    get admin_services_path(service_category_id: category.id), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    editor = document.at_css("[data-category-inline-editor]")

    expect(response).to have_http_status(:ok)
    expect(editor).to be_present
    expect(editor.at_css(".services-category-heading").text).to eq("Nails")
    expect(editor.at_css("[data-category-inline-edit]")).to be_present
    expect(editor.at_css("[data-service-category-modal='service-category-delete-modal-#{category.id}']")).to be_present
    expect(editor.at_css('input[name="service_category[name]"]')).to be_present
    expect(document.at_css(".services-category-sidebar-action")).to be_nil
    expect(document.at_css("#service-category-edit-modal-#{category.id}")).to be_nil
    expect(document.at_css('textarea[name="service_category[description]"]')).to be_nil
  end

  it "renames a service category through turbo stream without updating a category description" do
    user, business = create_admin_with_business
    service = create_service(business, name: "Esmaltado")
    category = service.service_category
    category.update!(name: "Nails", description: "Descripción original")

    sign_in(user)
    patch admin_service_category_path(category),
      params: { service_category: { name: "Beauty Nails", description: "No debería guardarse" } },
      headers: browser_headers.merge("Accept" => "text/vnd.turbo-stream.html")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include(%(target="services_category_heading_service_category_#{category.id}"))
    expect(response.body).to include(%(target="services_category_sidebar_name_service_category_#{category.id}"))
    expect(response.body).to include("Beauty Nails")
    expect(category.reload.name).to eq("Beauty Nails")
    expect(category.description).to eq("Descripción original")
  end

  it "attaches a cover image to a category and shows its thumbnail in the menu" do
    user, business = create_admin_with_business
    category = business.service_categories.create!(name: "Masajes", sort_order: 1)

    sign_in(user)
    patch admin_service_category_path(category),
      params: { service_category: { cover_image: service_image_upload } },
      headers: browser_headers

    expect(response).to redirect_to(admin_services_path(service_category_id: category.id))
    expect(category.reload.cover_image).to be_attached
    expect(category.cover_image.blob.key).to include("/imagenes/categorias/")

    follow_redirect!
    document = Nokogiri::HTML(response.body)
    category_link = document.css(".services-category-link").find { |link| link.text.squish.include?("Masajes") }

    thumbnail = category_link.at_css("img.services-category-thumbnail")
    preview_trigger = category_link.at_css("[data-category-image-preview]")

    expect(thumbnail).to be_present
    expect(preview_trigger["role"]).to eq("button")
    expect(preview_trigger["tabindex"]).to eq("0")
    expect(preview_trigger["data-category-image-preview-name"]).to eq("Masajes")
    expect(preview_trigger["data-category-image-preview-url"]).to include("service-gallery.png")
    expect(document.at_css("#services-category-image-preview-modal [data-category-image-preview-image]")).to be_present
    expect(document.at_css("[data-category-image-form] input[name='service_category[cover_image]']")).to be_present
  end

  it "renders the selected empty category heading with edit and delete controls" do
    user, business = create_admin_with_business
    category = business.service_categories.create!(name: "Cursos", sort_order: 1)

    sign_in(user)
    get admin_services_path(service_category_id: category.id), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    category_link = document.css(".services-category-link").find { |link| link.text.squish.include?("Cursos") }
    editor = document.at_css("[data-category-inline-editor]")
    delete_modal = document.at_css("#service-category-delete-modal-#{category.id}")

    expect(response).to have_http_status(:ok)
    expect(category_link).to be_present
    expect(category_link["class"]).to include("is-active")
    expect(document.at_css(".services-category-sidebar-action")).to be_nil
    expect(editor).to be_present
    expect(editor.at_css(".services-category-heading").text).to eq("Cursos")
    expect(editor.at_css("[data-category-inline-edit]")).to be_present
    expect(editor.at_css("[data-service-category-modal='service-category-delete-modal-#{category.id}']")).to be_present
    expect(document.text).to include("0 servicios disponibles")
    expect(document.text).to include("No hay servicios para mostrar")
    expect(document.at_css("#service-category-edit-modal-#{category.id}")).to be_nil
    expect(delete_modal).to be_present
    expect(delete_modal.text.squish).to include("Esta categoría no tiene servicios vinculados")
    expect(delete_modal.at_css("form")["action"]).to eq(admin_service_category_path(category))
  end

  it "deletes an empty service category" do
    user, business = create_admin_with_business
    category = business.service_categories.create!(name: "Cursos", sort_order: 1)

    sign_in(user)

    expect {
      delete admin_service_category_path(category), headers: browser_headers
    }.to change(ServiceCategory, :count).by(-1)

    expect(response).to redirect_to(admin_services_path)
    expect(ServiceCategory.exists?(category.id)).to eq(false)
  end

  it "redirects the old service show URL to the edit page" do
    user, business = create_admin_with_business
    service = create_service(business)

    sign_in(user)
    get admin_service_path(service), headers: browser_headers

    expect(response).to redirect_to(edit_admin_service_path(service))
  end

  it "renders the edit page with the same simple form used to add a service" do
    user, business = create_admin_with_business
    service = create_service(business, name: "Corte clásico", price_cents: 12_000_00)
    previous_app_host = ENV["APP_HOST"]
    ENV["APP_HOST"] = "https://example-ngrok.ngrok-free.app"

    host! "localhost:3000"
    sign_in(user)
    get edit_admin_service_path(service), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    public_link = document.at_css("a.service-editor-public-url")
    copy_button = document.at_css(".service-editor-public-url-copy")
    bottom_save_button = document.at_css(".service-editor-bottom-actions button[type='submit']")
    expected_public_url = public_category_service_url(slug: business.slug, category_slug: service.service_category.slug, service_slug: service.slug, host: "localhost:3000", protocol: "http")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Editar servicio")
    expect(response.body).to include("Corte clásico")
    expect(document.at_css('input[name="return_tab"]')).to be_present
    expect(public_link).to be_present
    expect(public_link["href"]).to eq(expected_public_url)
    expect(public_link["href"]).to include("/#{business.slug}/#{service.service_category.slug}/#{service.slug}")
    expect(public_link["href"]).not_to include("/reservar")
    expect(public_link["href"]).not_to include("service_id=")
    expect(public_link["href"]).not_to include("date=")
    expect(public_link.text).to include(expected_public_url)
    expect(public_link.text).not_to include("ngrok")
    expect(public_link["data-copy-text-target"]).to eq("source")
    expect(copy_button).to be_present
    expect(copy_button["title"]).to eq("Copiar")
    expect(copy_button["data-action"]).to eq("copy-text#copy")
    expect(bottom_save_button).to be_present
    expect(bottom_save_button.text.squish).to eq("Guardar")
    expect(document.at_css(".service-editor-step-footer")).to be_nil
    expect(document.at_css("[data-action='service-form-tabs#next']")).to be_nil
    expect(response.body).not_to include("Siguiente")
    expect(response.body).to include("Volver al listado")
    expect(response.body).to include("Información básica")
    expect(response.body).to include("Miembros del equipo")
    expect(response.body).to include("Imágenes")
    expect(response.body).to include("Horarios")
    expect(response.body).to include("Buscar profesional...")
    expect(response.body).to include("Seleccionar todos")
    expect(document.at_css('input[name="service[name]"]')).to be_present
    expect(document.at_css('select[name="service[service_category_id]"]')).to be_present
    expect(document.at_css('input[name="service[price]"]')).to be_present
    expect(document.at_css('input[type="checkbox"][name="service[deposit_required]"]')).to be_present
    expect(document.css(".service-toggle-control .service-toggle-checkbox").size).to be >= 2
    expect(document.at_css('input[name="service[deposit_amount]"]')).to be_present
    expect(document.css('a[href="/admin/configuracion#cobros-y-senas"]').map(&:text)).to include("Configuración")
    expect(document.at_css(".service-switch-label a[href='/admin/configuracion#cobros-y-senas']")).to be_nil
    expect(document.at_css("[data-service-deposit-target='amount'] a[href='/admin/configuracion#cobros-y-senas']")).to be_present
    expect(document.at_css('textarea[name="service[description]"]')).to be_present
    expect(response.body).not_to include("Página pública del servicio")
    expect(response.body).not_to include("Foto de portada")
    expect(response.body).not_to include("Disponibilidad y visibilidad")
    expect(response.body).not_to include("Vista rápida antes de guardar el servicio.")
  ensure
    ENV["APP_HOST"] = previous_app_host
  end

  it "shows the assigned team count in the service editor tab badge" do
    user, business = create_admin_with_business
    assigned_employee = create_employee(business, first_name: "Juan", last_name: "Perez")
    other_employee = create_employee(business, first_name: "Casa", last_name: "Tony")
    service = create_service(business, name: "Decoración")
    service.employee_memberships << assigned_employee

    sign_in(user)
    get edit_admin_service_path(service), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    team_tab = document.css(".service-editor-tab").find { |tab| tab.text.include?("Miembros del equipo asignados") }
    assigned_checkbox = document.at_css(%(input[name="service[employee_membership_ids][]"][value="#{assigned_employee.id}"]))
    other_checkbox = document.at_css(%(input[name="service[employee_membership_ids][]"][value="#{other_employee.id}"]))

    expect(response).to have_http_status(:ok)
    expect(team_tab.at_css(".service-editor-badge").text.strip).to eq("1")
    expect(document.at_css("#service_all_employee_memberships_checkbox")["checked"]).to be_nil
    expect(assigned_checkbox["checked"]).to eq("checked")
    expect(other_checkbox["checked"]).to be_nil
  end

  it "attaches service images from the edit service page" do
    user, business = create_admin_with_business
    service = create_service(business, name: "Decoración")

    sign_in(user)
    patch admin_service_path(service), params: {
      return_tab: "images",
      service: {
        name: service.name,
        service_category_id: service.service_category_id,
        duration_minutes: service.duration_minutes,
        price: "12000",
        description: service.description,
        all_employee_memberships: "1",
        service_images: [ service_image_upload ]
      }
    }, headers: browser_headers

    expect(response).to redirect_to(edit_admin_service_path(service, tab: "images"))
    expect(service.reload.service_images.attached?).to be(true)
    service_image_blob = service.service_images.attachments.first.blob
    expect(service_image_blob.service_name).to eq("service_images")
    expect(service_image_blob.key).to include("/imagenes/servicios/galeria/")

    follow_redirect!
    expect(response.body).to include("service-gallery.png")
  end

  it "expands and deletes a service image from the edit service page" do
    user, business = create_admin_with_business
    service = create_service(business, name: "Decoración")
    service.service_images.attach(service_image_upload)
    attachment = service.service_images.attachments.first
    blob = attachment.blob

    sign_in(user)

    get edit_admin_service_path(service, tab: "images"), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(data-action="service-image-upload#openSavedImage"))
    expect(response.body).to include(destroy_image_admin_service_path(service, attachment_id: attachment.id))
    expect(response.body).to include("Eliminar")

    expect {
      delete destroy_image_admin_service_path(service, attachment_id: attachment.id), headers: browser_headers
    }.to change(ActiveStorage::Attachment, :count).by(-1)
      .and change(ActiveStorage::Blob, :count).by(-1)

    expect(response).to redirect_to(edit_admin_service_path(service, tab: "images"))
    expect(service.reload.service_images.attached?).to eq(false)
    expect(ActiveStorage::Blob.exists?(blob.id)).to eq(false)
  end

  it "updates service date limits and weekly availability rules" do
    user, business = create_admin_with_business
    service = create_service(business, name: "Corte clásico")
    starts_on = 1.week.from_now.to_date
    ends_on = starts_on + 20.days

    sign_in(user)
    patch admin_service_path(service), params: {
      return_tab: "availability",
      service: {
        name: service.name,
        service_category_id: service.service_category_id,
        duration_minutes: service.duration_minutes,
        price: "12000",
        description: service.description,
        all_employee_memberships: "1",
        limit_availability_by_date: "1",
        availability_starts_on: starts_on.iso8601,
        availability_ends_on: ends_on.iso8601,
        use_advanced_availability: "1"
      },
      service_availability_rules: {
        "1" => {
          active: "1",
          intervals: {
            "0" => { start_time: "09:00", end_time: "12:00" },
            "1" => { start_time: "15:00", end_time: "18:00" }
          }
        },
        "2" => {
          active: "0",
          intervals: {
            "0" => { start_time: "09:00", end_time: "18:00" }
          }
        }
      }
    }, headers: browser_headers

    expect(response).to redirect_to(edit_admin_service_path(service, tab: "availability"))
    service.reload
    expect(service.limit_availability_by_date?).to eq(true)
    expect(service.availability_starts_on).to eq(starts_on)
    expect(service.availability_ends_on).to eq(ends_on)
    expect(service.use_advanced_availability?).to eq(true)
    expect(service.service_availability_rules.where(weekday: 1).order(:start_time).map { |rule| [ rule.start_time.strftime("%H:%M"), rule.end_time.strftime("%H:%M") ] }).to eq([
      [ "09:00", "12:00" ],
      [ "15:00", "18:00" ]
    ])
    expect(service.service_availability_rules.where(weekday: 2)).to be_empty

    follow_redirect!
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('input[name="return_tab"]')["value"]).to eq("availability")
    expect(document.at_css('input[type="checkbox"][name="service[limit_availability_by_date]"]')["checked"]).to eq("checked")
    expect(document.at_css('input[type="checkbox"][name="service[use_advanced_availability]"]')["checked"]).to eq("checked")
    expect(response.body).to include("Limitar la disponibilidad del servicio")
  end

  it "updates a service to apply all team members semantics" do
    user, business = create_admin_with_business
    employee = create_employee(business, first_name: "Wendy", last_name: "Smith")
    service = create_service(business, name: "Corte clásico")
    service.employee_memberships << employee

    sign_in(user)
    patch admin_service_path(service), params: {
      service: {
        name: service.name,
        service_category_id: service.service_category_id,
        duration_minutes: service.duration_minutes,
        price: "12000",
        description: service.description,
        all_employee_memberships: "1",
        employee_membership_ids: [ employee.id.to_s ]
      }
    }, headers: browser_headers

    expect(response).to redirect_to(edit_admin_service_path(service))
    expect(service.reload.employee_membership_ids).to eq([])

    follow_redirect!
    expect(response.body.scan("Servicio actualizado.").size).to eq(1)
    expect(response.body).to include(%(data-controller="flash-toast"))
    expect(response.body).to include(%(aria-label="Cerrar mensaje"))
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
      email_address: "admin-services-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )
    business = Business.create!(
      owner: user,
      name: "Navaja Club",
      slug: "navaja-club-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current,
      preferences: {
        "deposits_enabled" => true,
        "deposit_percentage" => 50
      }
    )

    [ user, business ]
  end

  def create_service(business, name: "Limpieza facial", price_cents: 10_000_00)
    category = ServiceCategory.find_or_create_for!(business: business, name: "Barbería", primary_category: true)
    business.services.create!(
      name: name,
      service_category: category,
      category: category.name,
      description: "Servicio de prueba.",
      duration_minutes: 60,
      price_cents: price_cents,
      active: true,
      visibility_mode: "public",
      public_visible: true
    )
  end

  def create_employee(business, first_name:, last_name:)
    business.employee_memberships.create!(
      first_name: first_name,
      last_name: last_name,
      email_address: "#{first_name.parameterize}-#{last_name.parameterize}-#{SecureRandom.hex(4)}@example.com",
      status: "active"
    )
  end

  def service_image_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/service-gallery.png").to_s,
      "image/png"
    )
  end
end
