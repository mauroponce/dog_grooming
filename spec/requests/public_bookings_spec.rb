require "rails_helper"
require "nokogiri"

RSpec.describe "Public bookings", type: :request do
  before do
    host! "localhost"
    allow_any_instance_of(ApplicationController).to receive(:verified_request?).and_return(true)
    allow(Ai::GeminiClient).to receive(:available?).and_return(false)
  end

  it "renders the service selection and lets customers continue to schedule by default" do
    business = create_business
    service = create_service(business)

    get new_public_booking_path(business.slug, service_id: service.slug, step: "services"), headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ver mis turnos")
    expect(response.body).not_to include(business.public_booking_headline)
    expect(response.body).not_to include("Confirmación inmediata")
    expect(response.body).to include("Seleccionar servicio")
    expect(response.body).to include("Esmaltado")
    expect(response.body).to include("No requiere seña")
    expect(response.body).to include("A pagar en el negocio")
    expect(response.body).not_to include("Destacados")
    expect(response.body).to include("Total")
    expect(document.at_css('a[href*="step=schedule"]')).to be_present
    expect(document.at_css('a[href*="step=professionals"]')).to be_nil
  end

  it "hides the public team section by default and shows it only when enabled" do
    business = create_business
    create_service(business)
    create_employee(business, "Sofia Perez")

    get public_business_path(business.slug), headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(document.at_css("#team-section")).to be_nil
    expect(document.css("nav a").map { |link| link.text.squish }).not_to include("Equipo")
    expect(response.body).not_to include("Sofia Perez")

    business.update!(preferences: business.preferences.merge("public_booking_show_team_members" => true))

    get public_business_path(business.slug), headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(document.at_css("#team-section")).to be_present
    expect(document.css("nav a").map { |link| link.text.squish }).to include("Equipo")
    expect(response.body).to include("Sofia Perez")
  end

  it "selects one service and keeps the customer on the service step until continuing" do
    business = create_business
    create_service(business)

    get new_public_booking_path(business.slug, step: "services"), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    detail_link = document.at_css("a[aria-label='Ver detalle de Esmaltado']")

    expect(response).to have_http_status(:ok)
    expect(detail_link).to be_present
    detail_query = query_params_for(detail_link["href"])
    expect(detail_query["step"]).to eq("services")
    expect(detail_query["service_detail"]).to eq("esmaltado")

    get detail_link["href"], headers: browser_headers

    detail_document = Nokogiri::HTML(response.body)
    detail_modal = detail_document.at_css("[data-public-service-detail-modal]")
    reserve_link = detail_modal.at_css("a[aria-label='Reservar Esmaltado']")

    expect(response).to have_http_status(:ok)
    expect(detail_modal).to be_present
    expect(detail_modal.text).to include("Esmaltado tradicional.")
    expect(reserve_link).to be_present
    reserve_query = query_params_for(reserve_link["href"])
    expect(reserve_query["step"]).to eq("services")
    expect(reserve_query["service_ids"]).to eq([ "esmaltado" ])

    get reserve_link["href"], headers: browser_headers

    selected_document = Nokogiri::HTML(response.body)
    selected_link = selected_document.at_css("a[aria-label='Ver detalle de Esmaltado']")
    continue_link = selected_document.at_css('a[href*="step=schedule"]')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar servicio")
    expect(selected_link["class"]).to include("border-brand-600")
    expect(continue_link).to be_present

    get continue_link["href"], headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar fecha y hora")
    expect(response.body).not_to include("Seleccionar profesional")
  end

  it "requires and preserves a pet-size variant before showing the schedule" do
    business = create_business
    service = create_service(business)
    service.update!(pricing_mode: "by_pet_size")
    bands = business.ensure_default_pet_size_bands!
    variants = bands.map.with_index do |band, index|
      service.service_variants.create!(pet_size_band: band, price_cents: (15_000 + index * 5_000) * 100, duration_minutes: 30 + index * 15)
    end

    get new_public_booking_path(business.slug, service_ids: [ service.slug ], step: "schedule"), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Elegí el tamaño para ver precio y duración")
    expect(response.body).to include("Grande · Más de 20 kg")
    expect(response.body).to include("$25.000 · 1 h")
    expect(response.body).to include("Seleccionar servicio")

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      service_variant_id: variants.last.id,
      step: "schedule"
    ), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar fecha y hora")
    expect(response.body).to include("$25.000")
  end

  it "collects the coat type but never exposes internal pet alerts in the public details step" do
    business = create_business
    service = create_service(business)
    starts_at = enable_availability_for(business, start_time: "09:00", end_time: "12:00")

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "details",
      starts_at: starts_at.iso8601
    ), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Tipo de manto")
    expect(response.body).to include('name="booking[pet_coat_type]"')
    expect(response.body).not_to include("Cuidados o información importante")
    expect(response.body).not_to include('name="booking[pet_notes]"')
  end

  it "shows booking times at the duration interval of the selected service" do
    business = create_business
    service = create_service(business)
    service.update!(duration_minutes: 45)
    starts_at = enable_availability_for(business, start_time: "09:00", end_time: "12:00")

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "schedule",
      date: starts_at.to_date,
      date_window_start: starts_at.to_date
    ), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    slot_labels = document.css("a[href*='starts_at']").filter_map do |link|
      starts_at_value = query_params_for(link["href"])["starts_at"]
      Time.zone.parse(starts_at_value)&.strftime("%H:%M") if starts_at_value.present?
    end

    expect(response).to have_http_status(:ok)
    expect(slot_labels).to eq([ "09:00", "09:45", "10:30", "11:15" ])
  end

  it "keeps the booking detail modal constrained and scrollable while preserving description line breaks" do
    business = create_business
    service = create_service(business)
    description = "Preparación incluida.\n\nTraé las uñas sin esmalte."
    service.update!(description: description)

    get new_public_booking_path(business.slug, step: "services", service_detail: service.slug), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    booking_header = document.at_css("[data-public-booking-header]")
    modal = document.at_css("[data-public-service-detail-modal]")
    modal_dialog = document.at_css("[data-public-service-detail-dialog]")
    modal_description = document.at_css("[data-public-service-detail-modal] [data-public-service-description]")
    modal_content = modal_dialog.at_css(".overflow-y-auto")

    expect(response).to have_http_status(:ok)
    expect(booking_header["class"]).to include("fixed", "inset-x-0", "top-0")
    expect(modal["class"]).to include("public-service-detail-overlay", "fixed", "inset-0", "z-[2147483646]", "overscroll-contain")
    expect(modal.parent["class"]).not_to include("z-10")
    expect(modal_dialog["class"]).to include("h-[560px]", "max-h-full", "overflow-hidden")
    expect(modal_content["class"]).to include("min-h-0", "flex-1", "overflow-y-auto", "overscroll-contain")
    expect(modal_description).to be_present
    expect(modal_description["class"]).to include("whitespace-pre-line")
    expect(modal_description.text).to include(description)
  end

  it "skips the professional step while customer selection is disabled" do
    business = create_business
    service = create_service(business)
    create_employee(business, "Sofia")
    create_employee(business, "Camila")
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "11:00")

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "professionals",
      professional_mode: "single",
      employee_membership_id: business.employee_memberships.first.id,
      date: starts_at.to_date
    ), headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar fecha y hora")
    expect(response.body).not_to include("Seleccionar profesional")
    expect(document.at_css("a[href*='step=professionals']")).to be_nil
  end

  it "selects a professional and keeps the customer on the professional step until continuing" do
    business = create_business
    enable_professional_selection(business)
    service = create_service(business)
    create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "professionals"
    ), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    professional_link = document.css("a[href*='employee_membership_id=#{camila.id}']").find { |link| link.text.include?("Camila") }

    expect(response).to have_http_status(:ok)
    expect(professional_link).to be_present
    professional_query = query_params_for(professional_link["href"])
    expect(professional_query["step"]).to eq("professionals")

    get professional_link["href"], headers: browser_headers

    selected_document = Nokogiri::HTML(response.body)
    selected_professional_link = selected_document.css("a[href*='employee_membership_id=#{camila.id}']").find { |link| link.text.include?("Camila") }
    summary_card = selected_document.at_css("[data-public-booking-summary]")
    mobile_footer = selected_document.at_css("[data-public-booking-mobile-footer]")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar profesional")
    expect(selected_document.at_css("[data-controller~='public-booking-flow']")).to be_present
    expect(selected_professional_link["class"]).to include("border-brand-600")
    expect(summary_card["class"]).to include("hidden")
    expect(summary_card["class"]).to include("lg:block")
    expect(summary_card.text).to include("$15.000")
    expect(summary_card.text).to include("Camila")
    expect(summary_card.text).not_to include("30 min")
    expect(summary_card.at_css('a[href*="step=schedule"]')).to be_present
    expect(mobile_footer["class"]).to include("fixed")
    expect(mobile_footer["class"]).to include("lg:hidden")
    expect(mobile_footer.text).to include("$15.000")
    expect(mobile_footer.text).not_to include("desde $15.000")
    expect(mobile_footer.text).to include("1 artículo")
    expect(mobile_footer.text).to include("30 min")
    expect(mobile_footer.at_css('a[href*="step=schedule"]')).to be_present
  end

  it "selects a time and keeps the customer on the schedule step until continuing" do
    business = create_business
    service = create_service(business)
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "11:00")

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "schedule",
      professional_mode: "any",
      date: starts_at.to_date
    ), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    slot_link = document.css("a").find { |link| link.text.strip == "10:00" }

    expect(response).to have_http_status(:ok)
    expect(slot_link).to be_present
    slot_query = query_params_for(slot_link["href"])
    expect(slot_query["step"]).to eq("schedule")
    expect(slot_query["starts_at"]).to be_present

    get slot_link["href"], headers: browser_headers

    selected_document = Nokogiri::HTML(response.body)
    selected_slot_link = selected_document.css("a").find { |link| link.text.strip == "10:00" }
    summary_card = selected_document.at_css("[data-public-booking-summary]")
    mobile_footer = selected_document.at_css("[data-public-booking-mobile-footer]")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar fecha y hora")
    expect(response.body).not_to include("Confirmar reserva")
    expect(selected_slot_link["class"]).to include("border-brand-600")
    expect(summary_card["class"]).to include("hidden")
    expect(summary_card["class"]).to include("lg:block")
    expect(summary_card.text).to include("$15.000")
    expect(summary_card.text).to include("10:00hs")
    expect(summary_card.text).not_to include("cualquier profesional")
    expect(summary_card.text).not_to include("Con ")
    expect(summary_card.text).not_to include("30 min")
    expect(summary_card.at_css('a[href*="step=details"]')).to be_present
    expect(mobile_footer.text).to include("$15.000")
    expect(mobile_footer.text).not_to include("desde $15.000")
    expect(mobile_footer.text).to include("1 artículo")
    expect(mobile_footer.text).to include("30 min")
    expect(mobile_footer.at_css('a[href*="step=details"]')).to be_present
  end

  it "opens the category service URL directly in the booking flow without date params" do
    business = create_business
    service = create_service(business, slug: "esmaltado")

    get public_category_service_path(business.slug, service.service_category.slug, service.slug), headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(request.path).to eq("/#{business.slug}/#{service.service_category.slug}/#{service.slug}")
    expect(request.query_string).to be_blank
    expect(response.body).to include("Seleccionar fecha y hora")
    expect(response.body).not_to include("Seleccionar profesional")
    expect(response.body).to include("Esmaltado")
    expect(document.at_css('a[href*="service_id=esmaltado"]')).to be_nil
  end

  it "renders service image thumbnails and a gallery modal in the service detail" do
    business = create_business
    service = create_service(business, name: "Corte de pelo", slug: "corte-de-pelo")
    service.service_images.attach(service_image_upload)
    service.service_images.attach(service_image_upload)

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      service_detail: service.slug
    ), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    thumbnails = document.css("[data-public-service-gallery-target='thumbnail']")
    gallery_modal = document.at_css("[data-public-service-gallery-target='modal']")
    gallery_close_button = gallery_modal.at_css("[aria-label='Cerrar galería']")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Corte de pelo")
    expect(document.at_css("[data-controller='public-service-gallery']")).to be_present
    expect(thumbnails.size).to eq(2)
    expect(thumbnails.first["data-action"]).to eq("public-service-gallery#open")
    expect(thumbnails.first["data-public-service-gallery-url"]).to include("/rails/active_storage/blobs")
    expect(gallery_modal).to be_present
    expect(gallery_modal.text).to include("1/2")
    expect(document.at_css("[data-public-service-gallery-target='previousButton']")).to be_present
    expect(document.at_css("[data-public-service-gallery-target='nextButton']")).to be_present
    expect(gallery_close_button).to be_present
    expect(gallery_close_button["data-action"]).to eq("public-service-gallery#close")
    expect(gallery_close_button["class"]).to include("absolute")
    expect(gallery_close_button.text.strip).to eq("×")
  end

  it "shows the configured Mercado Pago option without client-side method selection" do
    business = create_business
    business.update!(preferences: business.preferences.merge("deposits_enabled" => true, "enabled_payment_methods" => [ "manual_transfer", "mercado_pago" ]))
    business.create_mercado_pago_connection!(
      access_token: "mp-token",
      refresh_token: "mp-refresh",
      mercado_pago_user_id: "123",
      connected_at: Time.current
    )
    account = business.payment_accounts.create!(
      name: "BBVA principal",
      details: "Banco: BBVA\nAlias: CASA.TONY\nCBU: 0170132220000000890016",
      primary_account: true
    )
    service = create_service(business)
    service.update!(deposit_required: true, deposit_amount_cents: 3_500_00, payment_account: account)
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "12:00")

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "details",
      starts_at: starts_at.iso8601
    ), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Responsable y mascota")
    expect(response.body).not_to include("Comentario para el negocio")
    expect(response.body).not_to include("Comentario para el profesional")
    expect(response.body).not_to include("Elegí cómo pagar la seña")

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "details",
          service_ids: [ service.slug ],
          professional_mode: "any",
          starts_at: starts_at.iso8601,
          customer_name: "Julieta Perez",
          customer_phone: "+54 9 11 1111-1111",
          customer_email: "julieta@example.com",
          pet_name: "Coco"
        }
      },
      headers: browser_headers

    expect(response).to redirect_to(/step=reserve/)
    get response.location, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    payment_form = document.at_css("form#public_booking_payment_method_form")
    payment_step_input = payment_form.at_css("input[name='booking[submission_step]']")
    payment_form_buttons = document.css("button[form='public_booking_payment_method_form']").map { |button| button.text.squish }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Reservar")
    expect(response.body).to include("Método de pago de la seña")
    expect(response.body).to include("Mercado Pago")
    expect(response.body).not_to include("Elegí cómo pagar la seña")
    expect(response.body).not_to include("Transferencia por Alias / CBU")
    expect(payment_form["data-turbo"]).to eq("false")
    expect(payment_step_input["value"]).to eq("mercado_pago")
    expect(document.css("input[type='radio'][name='booking[submission_step]']")).to be_empty
    expect(payment_form_buttons).to eq([ "Reservar", "Reservar" ])
  end

  it "creates a temporary deposit booking when the customer starts transfer payment" do
    business = create_business
    business.update!(preferences: business.preferences.merge("deposits_enabled" => true, "enabled_payment_methods" => [ "manual_transfer" ]))
    business.payment_accounts.create!(
      name: "BBVA principal",
      details: "Alias: CASA.TONY",
      primary_account: true
    )
    service = create_service(business)
    service.update!(deposit_required: true, deposit_amount_cents: 3_500_00)
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "12:00")

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "details",
          service_ids: [ service.slug ],
          professional_mode: "any",
          starts_at: starts_at.iso8601,
          customer_name: "Julieta Perez",
          customer_phone: "+54 9 11 1111-1111",
          customer_email: "julieta@example.com",
          pet_name: "Coco",
          pet_coat_type: "other",
          pet_coat_details: "Manto mixto",
          pet_notes: "No guardar esta nota",
          pet_behavioral_alerts: [ "bite_risk" ]
        }
      },
      headers: browser_headers

    draft_token = query_params_for(response.location).fetch("draft")

    get response.location, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Al continuar, te mostraremos los datos para transferir la seña.")
    expect(response.body).not_to include("Ver datos para transferir")

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "start_manual_transfer",
          draft_token: draft_token
        }
      },
      headers: browser_headers

    appointment = business.appointments.last
    expect(response).to have_http_status(:redirect)
    expect(response.location).to include("step=reserve")
    expect(appointment).to be_manual_payment_required
    expect(appointment.pet).to have_attributes(
      name: "Coco",
      customer_profile: appointment.customer_profile,
      coat_type: "other",
      coat_details: "Manto mixto",
      notes: nil,
      behavioral_alerts: []
    )
    expect(appointment.deposit_amount_cents).to eq(3_500_00)
    expect(appointment.payment_charge_mode).to eq("deposit")
    expect(appointment.status).to eq("pending_deposit")

    get response.location, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    upload_form = document.at_css("form#public_booking_manual_upload_form")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Alias: CASA.TONY")
    expect(upload_form).to be_present
    expect(upload_form.at_css("input[name='booking[submission_step]']")["value"]).to eq("upload_manual_transfer")
    expect(document.css("button[form='public_booking_manual_upload_form']").map { |button| button.text.squish }).to eq([ "Enviar comprobante", "Enviar comprobante" ])
  end

  it "keeps only the active booking draft in the cookie-backed session" do
    business = create_business
    service = create_service(business)
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "12:00")
    draft_tokens = []

    18.times do
      post public_bookings_path(business.slug),
        params: {
          booking: {
            submission_step: "details",
            service_ids: [ service.slug ],
            professional_mode: "any",
            starts_at: starts_at.iso8601,
            customer_name: "Julieta Perez",
            customer_phone: "+54 9 11 1111-1111",
            customer_email: "julieta@example.com",
            pet_name: "Coco"
          }
        },
        headers: browser_headers

      expect(response).to have_http_status(:redirect)
      draft_tokens << query_params_for(response.location).fetch("draft")
    end

    expect(request.session.fetch(:public_booking_drafts).keys).to eq([ draft_tokens.last ])
  end

  it "keeps the payment labeled as deposit when the deposit covers the service total" do
    business = create_business
    business.update!(preferences: business.preferences.merge("deposits_enabled" => true, "enabled_payment_methods" => [ "manual_transfer" ]))
    business.payment_accounts.create!(
      name: "BBVA principal",
      details: "Alias: CASA.TONY",
      primary_account: true
    )
    service = create_service(business, price_cents: 15_000_00)
    service.update!(deposit_required: true, deposit_amount_cents: 15_000_00)
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "12:00")

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "details",
          service_ids: [ service.slug ],
          professional_mode: "any",
          starts_at: starts_at.iso8601,
          customer_name: "Julieta Perez",
          customer_phone: "+54 9 11 1111-1111",
          customer_email: "julieta@example.com",
          pet_name: "Coco"
        }
      },
      headers: browser_headers

    get response.location, headers: browser_headers

    expect(response.body).to include("Método de pago de la seña")
    expect(response.body).to include("Transferencia por Alias / CBU")
    expect(response.body).to include("Seña a pagar ahora: $15.000")
    expect(response.body).to include("A pagar el día del turno en el negocio: $0")
    expect(response.body).not_to include("pago total")

    draft_token = query_params_for(request.url).fetch("draft")
    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "start_manual_transfer",
          draft_token: draft_token
        }
      },
      headers: browser_headers

    appointment = business.appointments.last
    expect(appointment.payment_charge_mode).to eq("deposit")
    expect(appointment.deposit_amount_cents).to eq(15_000_00)
    expect(appointment.remaining_balance_cents).to eq(0)
  end

  it "starts Mercado Pago checkout for the deposit amount only" do
    business = create_business
    business.update!(preferences: business.preferences.merge("deposits_enabled" => true, "enabled_payment_methods" => [ "mercado_pago" ]))
    business.create_mercado_pago_connection!(
      access_token: "mp-token",
      refresh_token: "mp-refresh",
      mercado_pago_user_id: "123",
      connected_at: Time.current
    )
    service = create_service(business, price_cents: 20_000_00)
    service.update!(deposit_required: true, deposit_amount_cents: 4_000_00)
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "12:00")
    forwarded_headers = browser_headers.merge(
      "X-Forwarded-Host" => "51d9-187-61-184-88.ngrok-free.app",
      "X-Forwarded-Proto" => "https"
    )
    client = instance_double(MercadoPago::Client)
    captured_payload = nil
    allow(MercadoPago::Client).to receive(:new).and_return(client)
    allow(client).to receive(:create_preference!) do |payload|
      captured_payload = payload
      {
        "id" => "pref-test-123",
        "init_point" => "https://www.mercadopago.com.ar/checkout/v1/redirect?pref_id=pref-test-123",
        "sandbox_init_point" => "https://sandbox.mercadopago.com.ar/checkout/v1/redirect?pref_id=pref-test-123"
      }
    end

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "details",
          service_ids: [ service.slug ],
          professional_mode: "any",
          starts_at: starts_at.iso8601,
          customer_name: "Julieta Perez",
          customer_phone: "+54 9 11 1111-1111",
          customer_email: "julieta@example.com",
          pet_name: "Coco"
        }
      },
      headers: forwarded_headers

    draft_token = query_params_for(response.location).fetch("draft")

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "mercado_pago",
          draft_token: draft_token
        }
      },
      headers: forwarded_headers

    appointment = business.appointments.last
    payment = appointment.appointment_payment

    expect(response).to redirect_to("https://sandbox.mercadopago.com.ar/checkout/v1/redirect?pref_id=pref-test-123")
    expect(appointment).to be_pending_payment
    expect(appointment).to be_mercado_pago_payment_required
    expect(appointment.payment_charge_mode).to eq("deposit")
    expect(appointment.deposit_amount_cents).to eq(4_000_00)
    expect(appointment.remaining_balance_cents).to eq(16_000_00)
    expect(payment.amount_cents).to eq(4_000_00)
    expect(payment.appointment_ids).to eq([ appointment.id ])
    expect(captured_payload.dig(:items, 0, :unit_price)).to eq(4_000.0)
    expect(captured_payload.dig(:items, 0, :title)).to include("Reserva")
    expect(captured_payload.dig(:back_urls, :success)).to start_with("https://51d9-187-61-184-88.ngrok-free.app/#{business.slug}?")
    expect(captured_payload.dig(:back_urls, :success)).to include("confirmation=")
    expect(captured_payload.dig(:back_urls, :success)).to include("&mp_status=success")
    expect(captured_payload[:notification_url]).to start_with("https://51d9-187-61-184-88.ngrok-free.app/webhooks/mercado-pago")
  end

  it "uploads a transfer receipt from the reserve step and notifies the business" do
    business = create_business
    business.update!(preferences: business.preferences.merge("deposits_enabled" => true, "enabled_payment_methods" => [ "manual_transfer" ]))
    business.payment_accounts.create!(
      name: "BBVA principal",
      details: "Alias: CASA.TONY",
      primary_account: true
    )
    service = create_service(business)
    service.update!(deposit_required: true, deposit_amount_cents: 3_500_00)
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "12:00")

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "details",
          service_ids: [ service.slug ],
          professional_mode: "any",
          starts_at: starts_at.iso8601,
          customer_name: "Julieta Perez",
          customer_phone: "+54 9 11 1111-1111",
          customer_email: "julieta@example.com",
          pet_name: "Coco"
        }
      },
      headers: browser_headers

    draft_token = query_params_for(response.location).fetch("draft")

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "start_manual_transfer",
          draft_token: draft_token
        }
      },
      headers: browser_headers

    appointment = business.appointments.last

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "upload_manual_transfer",
          draft_token: draft_token,
          appointment_token: appointment.deposit_upload_token,
          deposit_receipt: service_image_upload
        }
      },
      headers: browser_headers

    appointment.reload
    event = business.provider_events.where(event_type: "deposit_receipt_submitted").last

    expect(response).to have_http_status(:redirect)
    expect(URI(response.location).path).to eq(public_business_path(business.slug))
    expect(Rack::Utils.parse_query(URI(response.location).query).fetch("confirmation")).to be_present
    expect(appointment).to be_pending_deposit_review
    expect(appointment.deposit_receipt).to be_attached
    expect(event.metadata.fetch("action_url")).to eq(appointment.deposit_review_url)
  end

  it "expires the temporary transfer booking when the upload deadline passed" do
    business = create_business
    business.update!(preferences: business.preferences.merge("deposits_enabled" => true, "enabled_payment_methods" => [ "manual_transfer" ]))
    business.payment_accounts.create!(
      name: "BBVA principal",
      details: "Alias: CASA.TONY",
      primary_account: true
    )
    service = create_service(business)
    service.update!(deposit_required: true, deposit_amount_cents: 3_500_00)
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "12:00")

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "details",
          service_ids: [ service.slug ],
          professional_mode: "any",
          starts_at: starts_at.iso8601,
          customer_name: "Julieta Perez",
          customer_phone: "+54 9 11 1111-1111",
          customer_email: "julieta@example.com",
          pet_name: "Coco"
        }
      },
      headers: browser_headers

    draft_token = query_params_for(response.location).fetch("draft")

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "start_manual_transfer",
          draft_token: draft_token
        }
      },
      headers: browser_headers

    reserve_url = response.location
    appointment = business.appointments.last
    appointment.update!(created_at: 31.minutes.ago)

    get reserve_url, headers: browser_headers

    expect(response).to redirect_to(public_business_path(business.slug))
    expect(appointment.reload).to be_expired
  end

  it "keeps personal data step from creating a booking and confirms no-payment services on reserve" do
    business = create_business
    service = create_service(business)
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "12:00")

    expect {
      post public_bookings_path(business.slug),
        params: {
          booking: {
            submission_step: "details",
            service_ids: [ service.slug ],
            professional_mode: "any",
            starts_at: starts_at.iso8601,
            customer_name: "Julieta Perez",
            customer_phone: "+54 9 11 1111-1111",
            customer_email: "julieta@example.com",
            pet_name: "Coco"
          }
        },
        headers: browser_headers
    }.not_to change { business.appointments.count }

    draft_token = query_params_for(response.location).fetch("draft")

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "confirm",
          draft_token: draft_token
        }
      },
      headers: browser_headers

    appointment = business.appointments.last
    expect(response).to have_http_status(:redirect)
    expect(URI(response.location).path).to eq(public_business_path(business.slug))
    expect(Rack::Utils.parse_query(URI(response.location).query).fetch("confirmation")).to be_present
    expect(appointment).to be_confirmed
    expect(appointment.customer_name).to eq("Julieta Perez")

    get response.location, headers: browser_headers

    expect(response.body).to include(appointment.customer_portal_booking_url)
    expect(response.body).not_to include("Guardá este link para consultar el estado de tus turnos:")
  end

  it "confirms the booking when returning from Mercado Pago with an approved payment" do
    business = create_business
    service = create_service(business)
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "12:00")
    business.create_mercado_pago_connection!(
      access_token: "mp-token",
      refresh_token: "mp-refresh",
      mercado_pago_user_id: "123",
      connected_at: Time.current
    )
    appointment = business.appointments.create!(
      service: service,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111",
      starts_at: starts_at,
      ends_at: starts_at + service.duration_minutes.minutes,
      status: :pending_payment,
      source: :public_booking,
      deposit_status: "pending",
      deposit_amount_cents: 3_500_00,
      payment_collection_method: "mercado_pago",
      payment_charge_mode: "deposit",
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )
    payment = AppointmentPayment.create!(
      business: business,
      appointment: appointment,
      provider: "mercado_pago",
      status: "pending",
      amount_cents: 3_500_00,
      currency: "ARS",
      external_reference: "mp-test-reference"
    )
    client = instance_double(MercadoPago::Client)
    allow(MercadoPago::Client).to receive(:new).and_return(client)
    allow(client).to receive(:fetch_payment!).with("123456").and_return(
      "id" => "123456",
      "status" => "approved",
      "transaction_amount" => 3_500,
      "currency_id" => "ARS",
      "collector_id" => "123",
      "external_reference" => payment.external_reference
    )

    token = appointment.signed_id(expires_in: 30.days, purpose: :public_booking_confirmation)

    get public_business_path(business.slug, confirmation: token, mp_status: "success", payment_id: "123456"), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Tu turno quedó confirmado")
    expect(appointment.reload).to be_confirmed
    expect(payment.reload).to be_approved
    event = business.provider_events.find_by!(event_type: "new_booking")
    expect(event.metadata["appointment_id"]).to eq(appointment.id)
  end

  it "ignores extra service ids in the public booking flow" do
    business = create_business
    enable_professional_selection(business)
    service = create_service(business)
    second_service = create_service(business, name: "Capping", slug: "capping", price_cents: 30_000_00)
    sofia = create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    date = enable_availability_for(business, start_time: "10:00", end_time: "11:00").to_date

    sofia.employee_availability_rules.find_by!(weekday: date.wday).update!(
      active: true,
      start_time: "10:00",
      end_time: "11:00",
      inherits_business_hours: false
    )
    camila.employee_availability_rules.find_by!(weekday: date.wday).update!(
      active: true,
      start_time: "10:00",
      end_time: "11:00",
      inherits_business_hours: false
    )

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug, second_service.slug ],
      step: "professionals",
      professional_mode: "per_service"
    ), headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar profesional")
    expect(response.body).to include(service.name)
    expect(response.body).not_to include(second_service.name)
    expect(document.at_css("select[name='professionals[#{service.slug}]']")).to be_nil
    expect(document.at_css("select[name='professionals[#{second_service.slug}]']")).to be_nil

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug, second_service.slug ],
      step: "schedule",
      professional_mode: "any",
      date: date
    ), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("10:00")
    expect(response.body).to include(service.name)
    expect(response.body).not_to include(second_service.name)
  end

  it "shows any-professional slots and filters them when a professional is selected" do
    business = create_business
    enable_professional_selection(business)
    service = create_service(business)
    sofia = create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "11:00")
    date = starts_at.to_date

    [ sofia, camila ].each do |employee|
      employee.employee_availability_rules.find_by!(weekday: date.wday).update!(
        active: true,
        start_time: "10:00",
        end_time: "11:00",
        inherits_business_hours: false
      )
    end
    business.appointments.create!(
      service: service,
      employee_membership: sofia,
      customer_name: "Cliente ocupado",
      customer_phone: "+54 9 11 2222-2222",
      starts_at: starts_at,
      ends_at: starts_at + service.duration_minutes.minutes,
      status: :confirmed,
      source: :public_booking
    )

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "schedule",
      professional_mode: "any",
      date: date
    ), headers: browser_headers

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css("a").map { |link| link.text.squish }).to include("10:00")
    expect(response.body).to include("Sin preferencia")

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "schedule",
      professional_mode: "single",
      employee_membership_id: sofia.id,
      date: date
    ), headers: browser_headers

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css("a").map { |link| link.text.squish }).not_to include("10:00")

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "schedule",
      professional_mode: "single",
      employee_membership_id: camila.id,
      date: date,
      professional_modal: 1
    ), headers: browser_headers

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css("a").map { |link| link.text.squish }).to include("10:00")
    expect(response.body).to include("Sofia")
    expect(response.body).to include("Camila")
    expect(response.body).to include("Máxima disponibilidad")
  end

  it "preserves selected service and professional when using breadcrumbs" do
    business = create_business
    enable_professional_selection(business)
    service = create_service(business)
    create_service(business, name: "HIFU facial", slug: "hifu-facial", category: "HIFU", price_cents: 65_000_00)
    create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "11:00")
    date = starts_at.to_date

    camila.employee_availability_rules.find_by!(weekday: date.wday).update!(
      active: true,
      start_time: "10:00",
      end_time: "11:00",
      inherits_business_hours: false
    )

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "schedule",
      professional_mode: "single",
      employee_membership_id: camila.id,
      date: date
    ), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    service_breadcrumb = document.at_css("a[href*='step=services']")
    professional_breadcrumb = document.at_css("a[href*='step=professionals']")

    expect(response).to have_http_status(:ok)
    expect(service_breadcrumb).to be_present
    expect(professional_breadcrumb).to be_present
    service_query = query_params_for(service_breadcrumb["href"])
    professional_query = query_params_for(professional_breadcrumb["href"])
    expect(service_query["service_ids"]).to eq([ "esmaltado" ])
    expect(service_query["category"]).to eq("Beauty Nails")
    expect(professional_query["employee_membership_id"]).to eq(camila.id.to_s)

    get professional_breadcrumb["href"], headers: browser_headers

    professional_document = Nokogiri::HTML(response.body)
    selected_professional_link = professional_document.css("a[href*='employee_membership_id=#{camila.id}']").find { |link| link.text.include?("Camila") }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar profesional")
    expect(selected_professional_link["class"]).to include("border-brand-600")

    get service_breadcrumb["href"], headers: browser_headers

    service_document = Nokogiri::HTML(response.body)
    selected_service_link = service_document.at_css("a[aria-label='Ver detalle de Esmaltado']")
    selected_category_link = service_document.css("a").find { |link| link.text.strip == "Beauty Nails" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Seleccionar servicio")
    expect(selected_service_link["class"]).to include("border-brand-600")
    expect(selected_category_link["class"]).to include("bg-zinc-950")
    expect(service_document.text).not_to include("HIFU facial")
    expect(service_document.text).to include("Camila")
  end

  it "keeps the booking draft when returning to earlier steps" do
    business = create_business
    enable_professional_selection(business)
    service = create_service(business)
    create_employee(business, "Sofia")
    professional = create_employee(business, "Camila")
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "11:00")

    professional.employee_availability_rules.find_by!(weekday: starts_at.to_date.wday).update!(
      active: true,
      start_time: "10:00",
      end_time: "11:00",
      inherits_business_hours: false
    )

    post public_bookings_path(business.slug),
      params: {
        booking: {
          submission_step: "details",
          service_ids: [ service.slug ],
          professional_mode: "single",
          employee_membership_id: professional.id,
          starts_at: starts_at.iso8601,
          customer_name: "Julieta Perez",
          customer_phone: "+54 9 11 1111-1111",
          customer_email: "julieta@example.com",
          pet_name: "Coco",
          notes: "Prefiere turno por la mañana"
        }
      },
      headers: browser_headers

    draft_token = query_params_for(response.location).fetch("draft")
    get response.location, headers: browser_headers

    reserve_document = Nokogiri::HTML(response.body)
    service_breadcrumb = reserve_document.at_css("a[href*='step=services']")
    professional_breadcrumb = reserve_document.at_css("a[href*='step=professionals']")
    schedule_breadcrumb = reserve_document.at_css("a[href*='step=schedule']")

    [ service_breadcrumb, professional_breadcrumb, schedule_breadcrumb ].each do |link|
      query = query_params_for(link["href"])
      expect(query["draft"]).to eq(draft_token)
      expect(query["service_ids"]).to eq([ service.slug ])
    end
    expect(query_params_for(service_breadcrumb["href"])["starts_at"]).to eq(starts_at.iso8601)
    expect(query_params_for(professional_breadcrumb["href"])["employee_membership_id"]).to eq(professional.id.to_s)

    get service_breadcrumb["href"], headers: browser_headers

    service_document = Nokogiri::HTML(response.body)
    service_continue = service_document.at_css("a[href*='step=professionals']")
    expect(query_params_for(service_continue["href"])["draft"]).to eq(draft_token)
    expect(query_params_for(service_continue["href"])["starts_at"]).to eq(starts_at.iso8601)

    get professional_breadcrumb["href"], headers: browser_headers

    professional_document = Nokogiri::HTML(response.body)
    selected_professional = professional_document.css("a[href*='employee_membership_id=#{professional.id}']").find { |link| link.text.include?("Camila") }
    professional_continue = professional_document.at_css("a[href*='step=schedule']")
    expect(selected_professional["class"]).to include("border-brand-600")
    expect(query_params_for(professional_continue["href"])["starts_at"]).to eq(starts_at.iso8601)

    get schedule_breadcrumb["href"], headers: browser_headers

    schedule_document = Nokogiri::HTML(response.body)
    selected_slot = schedule_document.css("a").find { |link| link.text.strip == "10:00" }
    details_continue = schedule_document.at_css("a[href*='step=details']")
    expect(selected_slot["class"]).to include("border-brand-600")
    expect(query_params_for(details_continue["href"])["draft"]).to eq(draft_token)

    get details_continue["href"], headers: browser_headers

    details_document = Nokogiri::HTML(response.body)
    expect(details_document.at_css("input[name='booking[customer_name]']")["value"]).to eq("Julieta Perez")
    expect(details_document.at_css("input[name='booking[customer_phone]']")["value"]).to eq("+54 9 11 1111-1111")
    expect(details_document.at_css("input[name='booking[customer_email]']")["value"]).to eq("julieta@example.com")
    expect(details_document.at_css("textarea[name='booking[notes]']")).to be_nil
  end

  it "creates a single appointment even if multiple services are submitted" do
    business = create_business
    service = create_service(business)
    second_service = create_service(business, name: "Capping", slug: "capping", price_cents: 30_000_00)
    sofia = create_employee(business, "Sofia")
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "12:00")
    sofia.employee_availability_rules.find_by!(weekday: starts_at.to_date.wday).update!(
      active: true,
      start_time: "10:00",
      end_time: "12:00",
      inherits_business_hours: false
    )

    post public_bookings_path(business.slug),
      params: {
        booking: {
          service_ids: [ service.slug, second_service.slug ],
          professional_mode: "any",
          starts_at: starts_at.iso8601,
          customer_name: "Julieta Perez",
          customer_phone: "+54 9 11 1111-1111",
          customer_email: "julieta@example.com",
          pet_name: "Coco"
        }
      },
      headers: browser_headers

    appointments = business.appointments.order(:starts_at).to_a
    expect(response).to have_http_status(:redirect)
    expect(URI(response.location).path).to eq(public_business_path(business.slug))
    expect(Rack::Utils.parse_query(URI(response.location).query).fetch("confirmation")).to be_present
    expect(appointments.size).to eq(1)
    expect(appointments.first.service).to eq(service)
    expect(appointments.first.employee_membership).to be_present
  end

  it "does not create a booking when the customer chooses Mercado Pago but it is not connected" do
    business = create_business
    business.update!(preferences: business.preferences.merge("deposits_enabled" => true, "enabled_payment_methods" => [ "mercado_pago" ]))
    service = create_service(business)
    service.update!(deposit_required: true, deposit_amount_cents: 3_000_00)
    starts_at = enable_availability_for(business, start_time: "10:00", end_time: "12:00")

    expect {
      post public_bookings_path(business.slug),
        params: {
          booking: {
            service_ids: [ service.slug ],
            professional_mode: "any",
            starts_at: starts_at.iso8601,
            customer_name: "Julieta Perez",
            customer_phone: "+54 9 11 1111-1111",
            customer_email: "julieta@example.com",
            pet_name: "Coco",
            payment_method: "mercado_pago"
          }
        },
        headers: browser_headers
    }.not_to change { business.appointments.count }

    expect(response).to redirect_to(
      new_public_booking_path(
        business.slug,
        service_ids: [ service.slug ],
        step: "schedule",
        date: starts_at.to_date,
        professional_mode: "any"
      )
    )
    expect(flash[:alert]).to eq("Mercado Pago no está disponible para esta reserva.")
  end

  it "shows a no-slots state with next available date and waitlist actions" do
    business = create_business
    service = create_service(business)
    next_starts_at = enable_availability_for(business, start_time: "10:00", end_time: "11:00")
    empty_date = next_starts_at.to_date + 1.day
    business.availability_rules.find_by!(weekday: empty_date.wday).update!(active: false)

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "schedule",
      date: empty_date,
      date_window_start: empty_date
    ), headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sin citas disponibles para esta fecha")
    expect(response.body).to include("Disponible desde")
    expect(response.body).to include("Ir a la próxima fecha disponible")
    expect(response.body).to include("Únete a la lista de espera")
    expect(document.at_css("a[href*='step=waitlist']")).to be_present
  end

  it "only links enabled service dates in the public booking calendar" do
    business = create_business
    service = create_service(business)
    starts_on = Time.zone.today
    starts_on += 1.day until starts_on.monday?
    ends_on = starts_on + 21.days
    service.update!(
      limit_availability_by_date: true,
      availability_starts_on: starts_on,
      availability_ends_on: ends_on,
      use_advanced_availability: true
    )
    service.service_availability_rules.create!(weekday: 1, active: true, start_time: "10:00", end_time: "11:00")
    service.service_availability_rules.create!(weekday: 2, active: true, start_time: "10:00", end_time: "11:00")

    get new_public_booking_path(
      business.slug,
      service_ids: [ service.slug ],
      step: "schedule",
      date: starts_on - 1.day,
      calendar_open: 1
    ), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    monday_link = calendar_date_link(document, starts_on)
    tuesday_link = calendar_date_link(document, starts_on + 1.day)
    disabled_wednesday_link = calendar_date_link(document, starts_on + 2.days)
    disabled_before_range_link = calendar_date_link(document, starts_on - 1.day)

    expect(response).to have_http_status(:ok)
    expect(monday_link).to be_present
    expect(tuesday_link).to be_present
    expect(disabled_wednesday_link).to be_nil
    expect(disabled_before_range_link).to be_nil
    expect(response.body).to include("#{starts_on.day}")
  end

  it "creates waitlist entries with selected date and time window" do
    business = create_business
    service = create_service(business)
    desired_date = 4.days.from_now.to_date

    expect {
      post public_waitlist_entries_path(business.slug),
        params: {
          waitlist_entry: {
            service_ids: [ service.slug ],
            client_name: "Julieta Perez",
            client_phone: "+54 9 11 1111-1111",
            email: "julieta@example.com",
            preferences: [
              {
                date: desired_date.iso8601,
                period: "morning",
                label: "Mañana",
                start_time: "06:00",
                end_time: "12:00"
              }
            ]
          }
        },
        headers: browser_headers
    }.to change { business.waitlist_entries.count }.by(1)

    entry = business.waitlist_entries.last
    expect(response).to have_http_status(:redirect)
    expect(entry.service).to eq(service)
    expect(entry.desired_date).to eq(desired_date)
    expect(entry.preferred_time_windows.first).to include("period" => "morning", "start_time" => "06:00", "end_time" => "12:00")
  end

  it "filters waitlist notifications by released slot time window" do
    business = create_business
    service = create_service(business)
    starts_at = 4.days.from_now.change(hour: 10, min: 0, sec: 0)
    appointment = business.appointments.create!(
      service: service,
      customer_name: "Cliente cancelado",
      customer_phone: "+54 9 11 2222-2222",
      starts_at: starts_at,
      ends_at: starts_at + service.duration_minutes.minutes,
      status: :canceled,
      source: :public_booking
    )
    matching_entry = business.waitlist_entries.create!(
      service: service,
      client_name: "Julieta Perez",
      client_phone: "+54 9 11 1111-1111",
      desired_date: starts_at.to_date,
      preferred_time_windows: [ WaitlistEntry.normalize_time_window("morning") ],
      source: "public_page",
      status: "waiting"
    )
    non_matching_entry = business.waitlist_entries.create!(
      service: service,
      client_name: "Camila Perez",
      client_phone: "+54 9 11 3333-3333",
      desired_date: starts_at.to_date,
      preferred_time_windows: [ WaitlistEntry.normalize_time_window("night") ],
      source: "public_page",
      status: "waiting"
    )

    expect {
      WaitlistNotificationService.call(appointment)
    }.to change { business.provider_events.where(event_type: "waitlist_released_slot").count }.by(1)

    event = business.provider_events.where(event_type: "waitlist_released_slot").last
    expect(matching_entry.reload).to be_offered
    expect(non_matching_entry.reload).to be_waiting
    expect(event.metadata.fetch("waitlist_entry_ids")).to eq([ matching_entry.id ])
    expect(event.metadata.fetch("action_url")).to include("/admin/calendario")
    expect(event.metadata.fetch("action_url")).to include("waitlist=1")
    expect(event.metadata.fetch("start_time")).to eq("10:00")
  end

  def create_business
    owner = User.create!(
      email_address: "public-booking-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )

    Business.create!(
      owner: owner,
      name: "Casa Tony",
      slug: "casa-tony-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )
  end

  def create_service(business, name: "Esmaltado", slug: "esmaltado", category: "Beauty Nails", price_cents: 15_000_00)
    business.services.create!(
      name: name,
      slug: slug,
      category: category,
      description: "Esmaltado tradicional.",
      duration_minutes: 30,
      price_cents: price_cents,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )
  end

  def create_employee(business, name)
    first_name, last_name = name.split(" ", 2)
    business.employee_memberships.create!(
      name: name,
      first_name: first_name,
      last_name: last_name.presence || "Principal",
      email_address: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
      status: "active"
    )
  end

  def enable_professional_selection(business)
    business.update!(
      preferences: business.preferences.merge(
        "public_booking_allow_professional_selection" => true
      )
    )
  end

  def enable_availability_for(business, start_time:, end_time:)
    date = 3.days.from_now.to_date
    business.availability_rules.find_by!(weekday: date.wday).update!(
      active: true,
      start_time: start_time,
      end_time: end_time
    )
    Time.zone.local(date.year, date.month, date.day, start_time.split(":").first.to_i, start_time.split(":").last.to_i)
  end

  def browser_headers
    {
      "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36",
      "HTTP_USER_AGENT" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"
    }
  end

  def service_image_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/service-gallery.png").to_s,
      "image/png"
    )
  end

  def query_params_for(href)
    Rack::Utils.parse_nested_query(URI(href).query)
  end

  def calendar_date_link(document, date)
    document.css("a").find do |link|
      query_params_for(link["href"])["date"] == date.iso8601 && query_params_for(link["href"])["step"] == "schedule"
    end
  end
end
