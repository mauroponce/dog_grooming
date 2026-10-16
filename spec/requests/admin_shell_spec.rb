require "rails_helper"
require "nokogiri"

RSpec.describe "Admin shell", type: :request do
  before { host! "localhost" }

  it "redirects unauthenticated admin visits to the login screen" do
    get admin_calendar_path, headers: browser_headers

    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to be_blank
  end

  it "renders the admin shell without the old setup drawer" do
    user, business = create_admin_with_business

    host! "localhost:3000"
    sign_in(user)
    get admin_customer_profiles_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    public_link = document.at_css(".admin-public-booking-link")
    copy_source = document.at_css('[data-copy-text-target="source"]')
    copy_container = document.at_css(".admin-header-public-url")
    copy_button = copy_container.at_css('[data-copy-text-target="button"]')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(href="#{admin_home_path}"))
    expect(response.body).to include(%(data-tooltip="Inicio"))
    expect(response.body).to include(%(href="#{admin_calendar_path}"))
    expect(response.body).to include(%(data-tooltip="Calendario"))
    expect(response.body).to include(%(href="#{admin_dashboard_path}"))
    expect(response.body).to include(%(href="#{admin_settings_path}"))
    expect(response.body).to include(%(data-tooltip="Configuración"))
    expect(response.body).to include(%(href="#{admin_tutorials_path}"))
    expect(response.body).to include(%(data-tooltip="Tutoriales"))
    expect(response.body).not_to include("data-admin-setup-button")
    expect(response.body).not_to include("adminSetupDrawer")
    expect(response.body).not_to include("AdminSetupDrawer")
    expect(response.body).not_to include("Guía inicial")
    expect(response.body).not_to include("Prepará lo esencial de tu negocio")
    expect(response.body).not_to include("Configurá tus servicios")
    expect(response.body).not_to include("Administrá a los miembros de tu equipo")
    expect(response.body).not_to include("Establece los horarios de atención")
    expect(response.body).not_to include("Completar setup")
    expect(response.body).not_to include("Completar Setup")
    expect(response.body).not_to include("/admin/datos-generales")
    expect(public_link).to be_present
    expect(public_link.text.strip).to eq("http://localhost:3000/#{business.slug}")
    expect(public_link["href"]).to eq("http://localhost:3000/#{business.slug}")
    expect(copy_source.text.strip).to eq("http://localhost:3000/#{business.slug}")
    expect(copy_container["data-copy-text-update-title-value"]).to eq("false")
    expect(copy_button).to be_present
    expect(copy_button["title"]).to be_nil
    expect(copy_button["aria-label"]).to eq("Copiar")
    expect(response.body).to include(%(target="_blank"))
    expect(response.body).to include("Editar perfil")
    expect(response.body).to include(%(href="#{edit_admin_profile_path}"))
  end

  it "renders the mobile admin navigation hooks without forcing the desktop width" do
    user, = create_admin_with_business

    sign_in(user)
    get admin_calendar_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(document.at_css("[data-admin-mobile-menu-toggle]")).to be_present
    expect(document.at_css("#admin-main-sidebar[data-admin-sidebar]")).to be_present
    expect(document.at_css("[data-admin-mobile-menu-close]")).to be_present
    expect(document.at_css("[data-admin-mobile-sidebar-backdrop]")).to be_present
    expect(response.body).not_to include("min-w-[1120px]")
  end

  it "renders responsive calendar containers" do
    user, = create_admin_with_business

    sign_in(user)
    get admin_calendar_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(document.at_css(".calendar-toolbar")).to be_present
    expect(document.at_css(".calendar-toolbar-primary")).to be_present
    expect(document.at_css(".calendar-toolbar-secondary")).to be_present
    expect(document.at_css(".calendar-date-nav")).to be_present
    expect(document.at_css("#viewSelectorLabel").text.strip).to eq("Semana")
    expect(document.at_css("#viewCheckDay")["class"]).to include("hidden")
    expect(document.at_css("#viewCheckWeek")["class"]).not_to include("hidden")
    expect(document.at_css("#resourceHeaderViewport")["class"]).to include("hidden")
    expect(document.at_css("#dayCalendarShell")["class"]).to include("hidden")
    expect(document.at_css("#weekCalendarShell")["class"]).not_to include("hidden")
    expect(response.body).to include(%(let calendarView = "week";))
    expect(response.body).to include('channel="Turbo::StreamsChannel"')
    expect(response.body).to include("admin_appointments")
    expect(response.body).to include(%(setCalendarView("week", { resetDate: false });))
    expect(response.body).to include(%(variant: "customer-profile"))
    expect(response.body).to include(%(calendarUrl: appointment.url))
    expect(response.body).to include("@media (max-width: 820px)")
  end

  it "opens a calendar appointment with t and an opaque short UUID" do
    user, business = create_admin_with_business
    category = ServiceCategory.find_or_create_for!(business: business, name: "Estética", primary_category: true)
    service = business.services.create!(name: "Consulta", service_category: category, category: category.name, duration_minutes: 30, price_cents: 5_000_00, active: true)
    starts_at = 4.days.from_now.change(hour: 10, min: 0)
    appointment = business.appointments.create!(
      service: service,
      customer_name: "Ada Lovelace",
      customer_phone: "+54 9 11 3333-3333",
      starts_at: starts_at,
      ends_at: starts_at + 30.minutes,
      status: :confirmed,
      final_price_cents: service.price_cents
    )

    sign_in(user)
    get admin_calendar_path(t: appointment.short_uuid), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(const initialAppointmentToken = "#{appointment.short_uuid}";))
    expect(response.body).to include(%("id":"#{appointment.short_uuid}"))
    expect(response.body).not_to include(%("id":"#{appointment.id}"))
    expect(response.body).not_to include("appointment_id")
    expect(admin_appointment_path(appointment)).to eq(
      admin_calendar_path(date: starts_at.to_date.iso8601, t: appointment.short_uuid)
    )
    expect(cancel_admin_appointment_path(appointment)).to include(appointment.short_uuid)
    expect(cancel_admin_appointment_path(appointment)).not_to include(appointment.id.to_s)
  end

  it "uses the current forwarded domain for the public booking link" do
    user, business = create_admin_with_business
    forwarded_url = "https://51d9-187-61-184-88.ngrok-free.app/#{business.slug}"

    host! "localhost:3000"
    sign_in(user)
    get admin_customer_profiles_path, headers: browser_headers.merge(
      "HTTP_X_FORWARDED_HOST" => "51d9-187-61-184-88.ngrok-free.app",
      "HTTP_X_FORWARDED_PROTO" => "https"
    )

    document = Nokogiri::HTML(response.body)
    public_link = document.at_css(".admin-public-booking-link")
    copy_source = document.at_css('[data-copy-text-target="source"]')

    expect(response).to have_http_status(:ok)
    expect(public_link.text.strip).to eq(forwarded_url)
    expect(public_link["href"]).to eq(forwarded_url)
    expect(copy_source.text.strip).to eq(forwarded_url)
  end

  it "renders sidebar counters without an appointments badge" do
    user, business = create_admin_with_business
    category = ServiceCategory.find_or_create_for!(business: business, name: "Uñas", primary_category: true)
    service = business.services.create!(
      name: "Esmaltado",
      service_category: category,
      category: category.name,
      duration_minutes: 30,
      price_cents: 20_000_00,
      active: true
    )
    business.customer_profiles.create!(first_name: "Valentina", last_name: "Gómez", phone: "+54 9 11 1111-1111")
    employee = business.employee_memberships.create!(
      first_name: "Jennifer",
      last_name: "López",
      name: "Jennifer López",
      email_address: "jennifer-#{SecureRandom.hex(4)}@example.com",
      status: "active"
    )
    appointment_start = Time.zone.now.change(hour: 16, min: 0, sec: 0)
    business.appointments.create!(
      customer_name: "Valentina Gómez",
      customer_phone: "",
      service: service,
      employee_membership: employee,
      source: :manual,
      starts_at: appointment_start,
      ends_at: appointment_start + 30.minutes,
      status: :confirmed,
      final_price_cents: 20_000_00
    )

    sign_in(user)
    get admin_customer_profiles_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    badges_by_label = document.css(".admin-sidebar-link").to_h do |link|
      [
        link.at_css(".admin-sidebar-link-label").text.strip,
        link.at_css(".admin-sidebar-badge")&.text&.strip
      ]
    end

    expect(response).to have_http_status(:ok)
    expect(badges_by_label.fetch("Calendario")).to be_nil
    expect(badges_by_label.fetch("Servicios")).to eq("1")
    expect(badges_by_label.fetch("Clientes")).to eq("1")
    expect(badges_by_label.fetch("Equipo")).to eq("1")
  end

  it "renders the notification drawer from the shared header" do
    user, business = create_admin_with_business
    business.provider_events.create!(
      event_type: "internal_notice",
      title: "Comprobante pendiente",
      body: "Tenés un comprobante listo para revisar.",
      metadata: {}
    )

    sign_in(user)
    get admin_customer_profiles_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Abrir notificaciones")
    expect(response.body).to include("Centro de actividad")
    expect(response.body).to include("Notificaciones")
    expect(response.body).to include("Comprobante pendiente")
    expect(response.body).to include("Tenés un comprobante listo para revisar.")
    expect(response.body).to include("1 sin leer")
    expect(response.body).to include("Marcar todas como leídas")
  end

  it "uses violet styling hooks for unread notifications and neutral hooks for read ones" do
    user, business = create_admin_with_business
    business.provider_events.create!(
      event_type: "internal_notice",
      title: "Aviso sin leer",
      metadata: { action_url: admin_root_path }
    )
    business.provider_events.create!(
      event_type: "internal_notice",
      title: "Aviso leído",
      read_at: Time.current,
      metadata: { action_url: admin_root_path }
    )

    sign_in(user)
    get admin_customer_profiles_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    unread_card = document.css(".admin-notification-card").find { |card| card.text.include?("Aviso sin leer") }
    read_card = document.css(".admin-notification-card").find { |card| card.text.include?("Aviso leído") }

    expect(unread_card["class"]).to include("is-unread")
    expect(unread_card.at_css(".admin-notification-time")["class"]).to include("is-unread")
    expect(unread_card.at_css(".admin-notification-action")["class"]).to include("is-unread")
    expect(read_card["class"]).not_to include("is-unread")
    expect(read_card.at_css(".admin-notification-time")["class"]).not_to include("is-unread")
    expect(read_card.at_css(".admin-notification-action")["class"]).not_to include("is-unread")
  end

  it "shows pending deposit proofs in the Acciones notification section" do
    user, business = create_admin_with_business
    business.provider_events.create!(
      event_type: "deposit_receipt_submitted",
      title: "Comprobante pendiente",
      body: "Tenés un comprobante listo para revisar.",
      metadata: {}
    )

    sign_in(user)
    get admin_customer_profiles_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    actions_panel = document.at_css('[data-admin-notifications-category-panel="actions"]')
    appointments_panel = document.at_css('[data-admin-notifications-category-panel="appointments"]')

    expect(response).to have_http_status(:ok)
    expect(actions_panel.text).to include("Comprobante pendiente")
    expect(appointments_panel.text).not_to include("Comprobante pendiente")
  end

  it "marks every business notification as read from the notification drawer" do
    user, business = create_admin_with_business
    first_event = business.provider_events.create!(
      event_type: "internal_notice",
      title: "Primer aviso",
      metadata: {}
    )
    second_event = business.provider_events.create!(
      event_type: "internal_notice",
      title: "Segundo aviso",
      metadata: {}
    )

    sign_in(user)

    expect {
      patch mark_all_read_admin_notifications_path, headers: browser_headers
    }.to change { business.provider_events.unread.count }.from(2).to(0)

    expect(response).to redirect_to(admin_home_path)
    expect(first_event.reload.read_at).to be_present
    expect(second_event.reload.read_at).to be_present
  end

  it "marks an individual notification as read and lets the admin delete it" do
    user, business = create_admin_with_business
    notification = business.provider_events.create!(
      event_type: "internal_notice",
      title: "Aviso individual",
      metadata: {}
    )

    sign_in(user)

    expect {
      patch mark_read_admin_notification_path(notification), headers: browser_headers
    }.to change { notification.reload.read_at }.from(nil)

    expect(response).to have_http_status(:no_content)

    expect {
      delete admin_notification_path(notification), headers: browser_headers
    }.to change { business.provider_events.count }.by(-1)

    expect(response).to redirect_to(admin_home_path)
  end

  it "renders delete and mark-read controls for each notification" do
    user, business = create_admin_with_business
    notification = business.provider_events.create!(
      event_type: "new_booking",
      title: "Nueva reserva para revisar",
      metadata: {}
    )

    sign_in(user)
    get admin_customer_profiles_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    card = document.css(".admin-notification-card").find { |item| item.text.include?(notification.title) }

    expect(card["data-admin-notification-mark-read-url"]).to eq(mark_read_admin_notification_path(notification))
    expect(card.at_css(".admin-notification-delete").text).to eq("Eliminar")
    expect(card.at_css(".admin-notification-delete-form")["action"]).to eq(admin_notification_path(notification))
  end

  it "only exposes the admin areas and their supporting controllers" do
    admin_controllers = Rails.application.routes.routes.filter_map do |route|
      controller = route.defaults[:controller].to_s
      controller if controller.start_with?("admin/")
    end.uniq

    expect(admin_controllers).to contain_exactly(
      "admin/appointments",
      "admin/assistant_messages",
      "admin/availability_blocks",
      "admin/billing",
      "admin/calendar",
      "admin/client_notes",
      "admin/customer_profiles",
      "admin/customer_reminders",
      "admin/dashboard",
      "admin/employee_memberships",
      "admin/extras",
      "admin/home",
      "admin/home_opportunities",
      "admin/mercado_pago_connections",
      "admin/non_working_periods",
      "admin/notifications",
      "admin/profiles",
      "admin/service_categories",
      "admin/settings",
      "admin/services",
      "admin/tutorials",
      "admin/waitlist_entries"
    )
  end

  it "renders admin root, inicio, and calendario while redirecting legacy turnos" do
    user, = create_admin_with_business

    sign_in(user)

    get admin_root_path, headers: browser_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Buen día")

    get "/admin/inicio", headers: browser_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Próximos turnos")

    get "/admin/calendario", headers: browser_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Calendario")

    get "/admin/turnos", headers: browser_headers
    expect(response).to redirect_to("/admin/calendario")
  end

  it "renders the admin assistant chat page" do
    user, = create_admin_with_business

    sign_in(user)
    get admin_dashboard_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(request.path).to eq("/admin/asistente")
    expect(response.body).to include("Asistente Cita.pet")
    expect(response.body).to include("Consulta agenda, clientes, comprobantes y facturación")
    expect(response.body).to include("Tu asistente diario")
    expect(response.body).to include("¿Qué querés saber de")
    expect(response.body).to include("Preguntas frecuentes")
    expect(response.body).to include("¿Qué necesita mi atención hoy?")
    expect(response.body).to include("Huecos para llenar")
    expect(response.body).to include("Resumen semanal")
    expect(response.body).to include("Ver más preguntas")
    expect(response.body).to include("Resumen semanal")
    expect(response.body).to include("admin-ai-suggestion-more")
    expect(response.body).to include("data-admin-ai-chat")
    expect(response.body).to include("data-admin-ai-form")
    expect(response.body).to include(admin_assistant_messages_path)
  end

  it "answers the admin assistant using only the signed-in business context" do
    user, business = create_admin_with_business
    current_category = ServiceCategory.find_or_create_for!(business: business, name: "Uñas", primary_category: true)
    current_service = business.services.create!(
      name: "Esmaltado premium",
      service_category: current_category,
      category: current_category.name,
      duration_minutes: 45,
      price_cents: 20_000_00,
      active: true
    )
    appointment_start = Time.zone.now.change(hour: 16, min: 0, sec: 0)
    business.appointments.create!(
      customer_name: "Valentina Gómez",
      customer_phone: "",
      service: current_service,
      source: :manual,
      starts_at: appointment_start,
      ends_at: appointment_start + 45.minutes,
      status: :confirmed,
      final_price_cents: 20_000_00
    )

    _other_user, other_business = create_admin_with_business
    other_business.update!(name: "Centro No Visible")
    other_category = ServiceCategory.find_or_create_for!(business: other_business, name: "Depilación", primary_category: true)
    other_business.services.create!(
      name: "Depilación privada de otro negocio",
      service_category: other_category,
      category: other_category.name,
      duration_minutes: 30,
      price_cents: 99_000_00,
      active: true
    )
    expected_business = business
    allow(Ai::GeminiClient).to receive(:available?).and_return(true)
    expect(Ai::GeminiClient).to receive(:chat_text) do |system:, messages:, temperature:, max_tokens:, feature:, business:|
      prompt = messages.last.fetch(:content)

      expect(system).to include("negocio actual")
      expect(prompt).to include(business.name)
      expect(prompt).to include("Esmaltado premium")
      expect(prompt).to include("Valentina Gómez")
      expect(prompt).not_to include("Centro No Visible")
      expect(prompt).not_to include("Depilación privada de otro negocio")
      expect(temperature).to eq(0.25)
      expect(max_tokens).to eq(700)
      expect(feature).to eq("admin_dashboard_assistant")
      expect(business).to eq(expected_business)

      "Tenés un turno confirmado para Valentina a las 16:00."
    end

    sign_in(user)
    post admin_assistant_messages_path,
      params: { question: "¿Qué turnos tengo hoy?" },
      as: :json,
      headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq("answer" => "Tenés un turno confirmado para Valentina a las 16:00.")
  end

  it "answers the weekly business summary with confirmed appointments included" do
    user, business = create_admin_with_business
    category = ServiceCategory.find_or_create_for!(business: business, name: "Cejas", primary_category: true)
    service = business.services.create!(
      name: "Diseño de cejas",
      service_category: category,
      category: category.name,
      duration_minutes: 30,
      price_cents: 12_000_00,
      active: true
    )
    employee = business.employee_memberships.create!(
      first_name: "Julian",
      last_name: "Alvarez",
      name: "Julian Alvarez",
      email_address: "julian-#{SecureRandom.hex(4)}@example.com",
      status: "active"
    )
    confirmed_starts_at = 2.days.from_now.change(hour: 11, min: 0)
    pending_starts_at = 3.days.from_now.change(hour: 10, min: 0)
    business.appointments.create!(
      service: service,
      employee_membership: employee,
      customer_name: "Valentina Gómez",
      customer_phone: "",
      starts_at: confirmed_starts_at,
      ends_at: confirmed_starts_at + 30.minutes,
      source: :manual,
      status: :confirmed,
      final_price_cents: service.price_cents
    )
    business.appointments.create!(
      service: service,
      employee_membership: employee,
      customer_name: "Pepe Mugica",
      customer_phone: "+54 9 11 2222-2222",
      starts_at: pending_starts_at,
      ends_at: pending_starts_at + 30.minutes,
      source: :public_booking,
      status: :pending_payment,
      deposit_status: "pending",
      deposit_amount_cents: 3_000_00,
      payment_collection_method: "mercado_pago",
      payment_charge_mode: "deposit",
      final_price_cents: service.price_cents
    )

    allow(Ai::GeminiClient).to receive(:available?).and_return(true)
    expect(Ai::GeminiClient).not_to receive(:chat_text)

    sign_in(user)
    post admin_assistant_messages_path,
      params: { question: "¿Cómo viene el negocio esta semana?" },
      as: :json,
      headers: browser_headers

    answer = JSON.parse(response.body).fetch("answer")
    expect(response).to have_http_status(:ok)
    expect(answer).to include("Resumen:")
    expect(answer).to include("• 1 turno confirmado por $12.000.")
    expect(answer).to include("• 1 turno pendiente de seña, con $3.000 por cobrar.")
    expect(answer).to include("Próximo turno confirmado:")
    expect(answer).to include("Valentina Gómez —")
    expect(answer).to include("Servicio: Diseño de cejas.")
    expect(answer).to include("Lo más importante ahora:")
    expect(answer).to include("Contactá al cliente con seña pendiente")
    expect(answer).to include("Acciones sugeridas:")
    expect(answer).to include("Revisar los clientes con seña pendiente.")
    expect(answer).not_to include("Tuesday")
  end

  it "answers gap questions with available times and suggested customers" do
    user, business = create_admin_with_business
    service = instance_double(Service, name: "Diseño de cejas")
    customer = instance_double(CustomerProfile, name: "Ana Pérez", phone: "+54 9 11 5555-5555")
    gap = Availability::FillableGaps::Gap.new(
      starts_at: Time.zone.local(2026, 8, 3, 10, 0),
      ends_at: Time.zone.local(2026, 8, 3, 10, 30),
      duration_minutes: 30,
      employee_membership: nil,
      service_suggestions: [ service ],
      waitlist_count: 0
    )
    suggestion = Gaps::SuggestedCustomers::Suggestion.new(
      customer: customer,
      service: service,
      reason: "Cliente frecuente",
      reasons: [ "Cliente frecuente" ],
      score: 72,
      source: "frequent"
    )

    allow(Availability::FillableGaps).to receive(:new).and_return(instance_double(Availability::FillableGaps, call: [ gap ]))
    allow(Gaps::SuggestedCustomers).to receive(:new).and_return(instance_double(Gaps::SuggestedCustomers, call: [ suggestion ]))
    allow(Ai::GeminiClient).to receive(:available?).and_return(true)
    expect(Ai::GeminiClient).not_to receive(:chat_text)

    sign_in(user)
    post admin_assistant_messages_path,
      params: { question: "¿Qué huecos puedo llenar y a quién conviene escribirle?" },
      as: :json,
      headers: browser_headers

    answer = JSON.parse(response.body).fetch("answer")
    expect(response).to have_http_status(:ok)
    expect(answer).to include("hueco")
    expect(answer).to include("10:00-10:30")
    expect(answer).to include("Diseño de cejas")
    expect(answer).to include("Ana Pérez")
    expect(answer).to include("cliente frecuente")
    expect(answer).not_to include("turno confirmado")
  end

  it "answers today's attention question locally without requiring Gemini" do
    user, business = create_admin_with_business
    category = ServiceCategory.find_or_create_for!(business: business, name: "Cejas", primary_category: true)
    service = business.services.create!(
      name: "Diseño de cejas",
      service_category: category,
      category: category.name,
      duration_minutes: 30,
      price_cents: 12_000_00,
      active: true
    )
    starts_at = Time.zone.now.change(hour: 15, min: 0, sec: 0)
    starts_at += 1.day if starts_at.past?
    business.appointments.create!(
      service: service,
      customer_name: "Ana Pérez",
      customer_phone: "+54 9 11 5555-5555",
      starts_at: starts_at,
      ends_at: starts_at + 30.minutes,
      source: :public_booking,
      status: :pending_deposit_review,
      deposit_status: "submitted",
      deposit_amount_cents: 3_000_00,
      final_price_cents: service.price_cents
    )

    allow(Ai::GeminiClient).to receive(:available?).and_return(false)
    expect(Ai::GeminiClient).not_to receive(:chat_text)

    sign_in(user)
    post admin_assistant_messages_path,
      params: { question: "¿Qué necesita mi atención hoy?" },
      as: :json,
      headers: browser_headers

    answer = JSON.parse(response.body).fetch("answer")
    expect(response).to have_http_status(:ok)
    expect(answer).to include("Para hoy, priorizá esto:")
    expect(answer).to include("Revisá 1 comprobante pendiente")
    expect(answer).not_to include("fillable_gaps_today")
  end

  it "renders and updates general business data and opening hours from admin settings" do
    user, business = create_admin_with_business
    new_owner_email = "owner-settings-#{SecureRandom.hex(4)}@example.com"
    new_slug = "casa-tony-settings-#{SecureRandom.hex(4)}"

    sign_in(user)
    get admin_settings_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Configuración")
    expect(response.body).to include("Datos Generales")
    expect(response.body).to include("Nombre del centro")
    expect(response.body).to include("Nombre del dueño")
    expect(response.body).to include("Email de acceso del dueño")
    expect(response.body).to include("Link público")
    expect(response.body).to include("Dirección del negocio")
    expect(response.body).to include("Página de reservas")
    expect(response.body).to include("Asignación de turnos")
    expect(response.body).to include("Reprogramaciones")
    expect(response.body).to include("Permitir que el cliente elija profesional")
    expect(response.body).to include("Primer profesional disponible")
    expect(response.body).to include("Reparto equilibrado")
    expect(response.body).to include("Profesional con menor carga del día")
    expect(response.body).to include("Priorizar profesional habitual del cliente")
    expect(response.body).to include("Cuentas de cobro")
    expect(response.body).to include(%(data-logo-preview))
    expect(response.body).to include(%(data-logo-input))
    expect(response.body).not_to include("Pagos online")
    expect(response.body).to include("Métodos de pago habilitados")
    expect(response.body).to include("Elegí como se puede abonar la seña o el total al reservar un turno. Luego podés configurarlo por cada servicio.")
    expect(response.body).to include("Transferencia por Alias / CBU")
    expect(response.body).not_to include("Método de cobro por defecto")
    expect(response.body).to include("Datos de cuenta")
    expect(response.body).to include("Mercado Pago")
    expect(response.body).to include("Alias / CBU")
    expect(response.body).to include("Horarios de atención")
    expect(response.body).to include("Informá a los clientes el horario habitual del centro")
    expect(response.body).to include("Fechas no laborables")
    expect(response.body).to include("Añadir nueva")
    expect(response.body).to include(%(data-schedule-day-pill="1"))
    expect(response.body).to include("Guardar cambios")
    expect(document.at_css("#settings-active-tab")["value"]).to eq("datos-generales")
    expect(document.at_css("form#admin-settings-form")["data-turbo"]).to eq("false")

    save_buttons = document.css("form#admin-settings-form button[type='submit']").select do |button|
      button.text.strip == "Guardar cambios"
    end

    expect(save_buttons.size).to eq(2)
    expect(document.at_css(".settings-save-footer button[type='submit']")).to be_present
    expect(response.body).not_to include("settings-sidebar-title")
    expect(document.at_css("#datos-generales")).to be_present
    expect(document.at_css("#datos-generales")["hidden"]).to be_nil
    expect(document.at_css("#business_account_slogan")).to be_present
    expect(document.at_css("#business_account_owner_email")["required"]).to eq("required")
    expect(document.at_css("#business_account_contact_phone")["required"]).to eq("required")
    expect(document.at_css("#pagina-de-reservas")).to be_present
    expect(document.at_css("#pagina-de-reservas")["hidden"]).to eq("")
    expect(document.at_css("#booking_page_preferences_allow_professional_selection")["checked"]).to be_nil
    expect(document.at_css("#booking_page_preferences_show_team_members")["checked"]).to be_nil
    expect(document.at_css("#booking_page_preferences_assignment_strategy_first_available")["checked"]).to eq("checked")
    expect(document.at_css("#booking_page_preferences_rescheduling_notice_hours")["value"]).to eq("24")
    expect(document.at_css("#cuentas-de-cobro")).to be_present
    expect(document.at_css("#cuentas-de-cobro")["hidden"]).to eq("")
    expect(document.at_css("#cuentas-de-cobro").text).to include("Mercado Pago")
    expect(document.at_css("#cuentas-de-cobro").text).to include("Alias / CBU")
    expect(document.at_css("[data-payment-method-toggle='mercado-pago']")).to be_present
    expect(document.at_css("[data-payment-method-toggle='manual-transfer']")).to be_present
    expect(document.at_css("#pagos-online")).to be_nil
    expect(document.at_css("#horarios-de-atencion")).to be_present
    expect(document.at_css("#horarios-de-atencion")["hidden"]).to eq("")
    expect(document.at_css("#fechas-no-laborables")).to be_present
    expect(document.at_css("#fechas-no-laborables")["hidden"]).to eq("")
    expect(document.at_css("#non_working_period_starts_on")["form"]).to eq("non-working-period-form")
    expect(document.at_css("#non_working_period_ends_on")["form"]).to eq("non-working-period-form")
    expect(document.at_css("#non_working_period_starts_on")["type"]).to eq("hidden")
    expect(document.at_css("#non_working_period_ends_on")["type"]).to eq("hidden")
    expect(document.at_css("#non_working_period_starts_on_display")["type"]).to eq("text")
    expect(document.at_css("#non_working_period_ends_on_display")["type"]).to eq("text")
    expect(document.at_css("#non_working_period_starts_on_display")["placeholder"]).to eq("dd/mm/aaaa")
    expect(document.at_css("#non_working_period_ends_on_display")["placeholder"]).to eq("dd/mm/aaaa")
    expect(document.at_css("#non_working_period_starts_on_display")["inputmode"]).to eq("none")
    expect(document.at_css("#non_working_period_ends_on_display")["inputmode"]).to eq("none")
    expect(document.css('[data-controller="date-picker"]').size).to eq(2)
    expect(document.at_css("#non_working_period_starts_on_display")["data-action"]).to include("click->date-picker#open")
    expect(document.at_css("#non_working_period_ends_on_display")["data-action"]).to include("beforeinput->date-picker#preventManualInput")
    expect(document.css(".settings-date-picker-calendar").size).to eq(2)
    expect(response.body).to include("event.preventDefault()")
    expect(response.body).to include("La fecha hasta debe ser posterior a la fecha desde.")

    patch admin_settings_path, params: {
      settings_tab: "cuentas-de-cobro",
      business_account: {
        business_name: "Casa Tony",
        owner_name: "Mauro Ponce",
        owner_email: new_owner_email,
        contact_phone: "+54 9 11 3211-8817",
        slug: new_slug,
        instagram_url: "casa.tony",
        slogan: "Belleza simple, turnos claros",
        address: "Jorge Santiago Bynnon 1839",
        latitude: "-34.8000000",
        longitude: "-58.4000000",
        city: "Adrogué",
        province: "Buenos Aires",
        neighborhood: "Adrogué"
      },
      payment_accounts: {
        primary_key: "new_primary",
        items: {
          "new_primary" => {
            name: "BBVA principal",
            details: "Banco: BBVA\nAlias: CASA.TONY\nCBU: 0170132220000000890016"
          },
          "new_secondary" => {
            name: "Mercado Pago",
            details: "Alias: CASA.TONY.MP"
          }
        }
      },
      payment_preferences: {
        enabled_payment_methods: [ "", "manual_transfer" ]
      },
      booking_page_preferences: {
        allow_professional_selection: "1",
        show_team_members: "1",
        assignment_strategy: "least_daily_load",
        rescheduling_notice_hours: "36"
      },
      availability_rules: Business::DAYS.to_h.transform_values.with_index do |_day_name, index|
        weekday = Business::DAYS[index].first
        {
          active: weekday.in?([ 1, 2 ]) ? "1" : "0",
          start_time: weekday == 1 ? "09:00" : "10:00",
          end_time: weekday == 1 ? "18:00" : "19:00",
          break_start_time: "",
          break_end_time: ""
        }
      end
    }, headers: browser_headers

    expect(response).to redirect_to(admin_settings_path(settings_tab: "cuentas-de-cobro", anchor: "cuentas-de-cobro"))
    business.reload
    user.reload
    expect(business.name).to eq("Casa Tony")
    expect(business.slug).to eq(new_slug)
    expect(business.contact_phone).to eq("+54 9 11 3211-8817")
    expect(business.instagram_url).to eq("https://www.instagram.com/casa.tony")
    expect(business.slogan).to eq("Belleza simple, turnos claros")
    expect(business.address).to eq("Jorge Santiago Bynnon 1839")
    expect(business.city).to eq("Adrogué")
    expect(business.province).to eq("Buenos Aires")
    expect(user.name).to eq("Mauro Ponce")
    expect(user.email_address).to eq(new_owner_email)
    expect(business.branches.find_by!(name: "Principal").address).to eq("Jorge Santiago Bynnon 1839")
    expect(business.employee_memberships.find_by!(user: user).name).to eq("Mauro Ponce")
    expect(business.payment_accounts.count).to eq(2)
    expect(business.primary_payment_account.name).to eq("BBVA principal")
    expect(business.primary_payment_account.details).to include("CBU: 0170132220000000890016")
    expect(business.enabled_payment_methods).to eq([ "manual_transfer" ])
    expect(business.public_booking_allow_professional_selection?).to eq(true)
    expect(business.public_booking_show_team_members?).to eq(true)
    expect(business.public_booking_assignment_strategy).to eq("least_daily_load")
    expect(business.rescheduling_notice_hours).to eq(36)
    monday = business.availability_rules.find_by!(weekday: 1)
    expect(monday).to be_active
    expect(monday.start_time.strftime("%H:%M")).to eq("09:00")
    expect(monday.end_time.strftime("%H:%M")).to eq("18:00")
    expect(business.availability_rules.find_by!(weekday: 2)).to be_active
    expect(business.availability_rules.find_by!(weekday: 3)).not_to be_active
  end

  it "redirects to the submitted settings tab after saving" do
    user, = create_admin_with_business

    sign_in(user)

    Admin::SettingsController::SETTINGS_TABS.each do |tab|
      patch admin_settings_path(settings_tab: tab), headers: browser_headers

      expect(response).to redirect_to(admin_settings_path(settings_tab: tab, anchor: tab))
    end
  end

  it "renders the tab selected by the settings redirect before JavaScript runs" do
    user, = create_admin_with_business

    sign_in(user)
    get admin_settings_path(settings_tab: "cuentas-de-cobro"), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    expect(document.at_css("#settings-active-tab")["value"]).to eq("cuentas-de-cobro")
    expect(document.at_css("#cuentas-de-cobro")["hidden"]).to be_nil
    expect(document.at_css("#datos-generales")["hidden"]).to eq("")
  end

  it "shows one Mercado Pago connection action for each connection state" do
    user, business = create_admin_with_business
    allow(MercadoPago::OAuthClient).to receive(:configured?).and_return(true)

    sign_in(user)
    get admin_settings_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    actions = document.at_css("[data-mercado-pago-connection-actions]")

    expect(response).to have_http_status(:ok)
    expect(actions.css("a").map { |link| link.text.squish }).to eq([ "Conectar" ])
    expect(actions.at_css("a")["href"]).to eq(connect_admin_mercado_pago_connection_path)

    business.create_mercado_pago_connection!(access_token: "mp-token", connected_at: Time.current)

    get admin_settings_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    actions = document.at_css("[data-mercado-pago-connection-actions]")
    disconnect_button = actions.at_css("button")

    expect(response).to have_http_status(:ok)
    expect(actions.css("button").map { |button| button.text.squish }).to eq([ "Desconectar" ])
    expect(disconnect_button["type"]).to eq("submit")
    expect(disconnect_button["form"]).to eq("mercado-pago-disconnect-form")
    expect(document.at_css("#mercado-pago-disconnect-form")["action"]).to eq(admin_mercado_pago_connection_path)
    expect(document.at_css("#mercado-pago-disconnect-form")["data-turbo"]).to eq("false")
  end

  it "disconnects Mercado Pago and returns to payment accounts" do
    user, business = create_admin_with_business
    connection = business.create_mercado_pago_connection!(access_token: "mp-token", connected_at: Time.current)

    sign_in(user)
    delete admin_mercado_pago_connection_path, headers: browser_headers

    expect(response).to redirect_to(admin_settings_path(settings_tab: "cuentas-de-cobro", anchor: "cuentas-de-cobro"))
    expect(connection.reload).not_to be_connected
    expect(business.reload.enabled_payment_methods).not_to include("mercado_pago")
  end

  it "does not allow an admin to clear the business phone or owner email" do
    user, business = create_admin_with_business

    sign_in(user)

    patch admin_settings_path, params: {
      settings_tab: "cuentas-de-cobro",
      business_account: {
        business_name: business.name,
        owner_name: user.name.presence || business.name,
        owner_email: user.email_address,
        contact_phone: "",
        slug: business.slug
      }
    }, headers: browser_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Completá el teléfono del negocio.")
    expect(Nokogiri::HTML(response.body).at_css("#settings-active-tab")["value"]).to eq("cuentas-de-cobro")
    expect(business.reload.contact_phone).to eq("+54 9 11 4444-4444")

    patch admin_settings_path, params: {
      business_account: {
        business_name: business.name,
        owner_name: user.name.presence || business.name,
        owner_email: " ",
        contact_phone: business.contact_phone,
        slug: business.slug
      }
    }, headers: browser_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Completá el email de acceso del dueño.")
    expect(user.reload.email_address).to be_present
  end

  it "adds and removes business-wide non-working date ranges from settings" do
    user, business = create_admin_with_business

    sign_in(user)
    post admin_non_working_periods_path, params: {
      non_working_period: {
        starts_on: "2026-08-10",
        ends_on: "2026-08-12"
      }
    }, headers: browser_headers

    period = business.availability_blocks.non_working_periods.last

    expect(response).to redirect_to(admin_settings_path(settings_tab: "fechas-no-laborables", anchor: "fechas-no-laborables"))
    expect(period.starts_at).to eq(Time.zone.local(2026, 8, 10))
    expect(period.ends_at).to eq(Time.zone.local(2026, 8, 13))
    expect(period.reason).to eq("Fecha no laborable")
    expect(period.online_booking_allowed).to eq(false)

    get admin_settings_path, headers: browser_headers

    expect(response.body).to include("10/08/2026 al 12/08/2026")

    delete admin_non_working_period_path(period), headers: browser_headers

    expect(response).to redirect_to(admin_settings_path(settings_tab: "fechas-no-laborables", anchor: "fechas-no-laborables"))
    expect(period.reload).to be_cancelled
  end

  it "rejects a non-working range whose end date is not after its start date" do
    user, business = create_admin_with_business

    sign_in(user)

    expect {
      post admin_non_working_periods_path, params: {
        non_working_period: {
          starts_on: "2026-08-10",
          ends_on: "2026-08-10"
        }
      }, headers: browser_headers
    }.not_to change { business.availability_blocks.non_working_periods.count }

    expect(response).to redirect_to(admin_settings_path(settings_tab: "fechas-no-laborables", anchor: "fechas-no-laborables"))
    expect(flash[:alert]).to eq("La fecha hasta debe ser posterior a la fecha desde.")
  end

  it "renders day, week, and month calendar views with the shared team filter" do
    user, = create_admin_with_business

    sign_in(user)
    get admin_calendar_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(setCalendarView('day')))
    expect(response.body).to include(%(setCalendarView('week')))
    expect(response.body).to include(%(setCalendarView('month')))
    expect(response.body).to include(%(id="weekCalendarShell"))
    expect(response.body).to include(%(id="teamSelectorButton"))
    expect(response.body).not_to include(%(id="calendarHoverCard"))
    expect(response.body).not_to include("showCalendarItemPreview")
    expect(response.body).to include("const START_HOUR = 0")
    expect(response.body).to include("const END_HOUR = 24")
    expect(response.body).to include("scrollCalendarToCurrentTime")
    expect(response.body).to include("setInterval(refreshCurrentTimeLine, 30_000)")
    expect(response.body).to match(/function setCalendarView\(view, options = \{\}\).*?selectedDate = new Date\(\)/m)
  end

  it "creates and deletes unavailable time blocks from the calendar" do
    user, business = create_admin_with_business
    employee = business.employee_memberships.create!(
      name: "Juan Perez",
      first_name: "Juan",
      last_name: "Perez",
      email_address: "juan-#{SecureRandom.hex(4)}@example.com",
      status: "active"
    )
    date = 2.days.from_now.to_date

    sign_in(user)
    post admin_availability_blocks_path(format: :json), params: {
      range_start: date.beginning_of_month.iso8601,
      range_end: date.end_of_month.iso8601,
      availability_block: {
        title: "No disponible",
        date: date.iso8601,
        start_time: "19:30",
        end_time: "20:30",
        employee_membership_id: employee.id,
        recurrence: "weekly",
        description: "Cena",
        online_booking_allowed: "0"
      }
    }, headers: browser_headers.merge("Accept" => "application/json")

    block = business.availability_blocks.last
    payload = response.parsed_body.fetch("blocks").first

    expect(response).to have_http_status(:created)
    expect(block.employee_membership).to eq(employee)
    expect(block.reason).to eq("No disponible")
    expect(block.recurrence).to eq("weekly")
    expect(block.description).to eq("Cena")
    expect(block.online_booking_allowed).to eq(false)
    expect(payload.fetch("employeeId")).to eq(employee.id.to_s)
    expect(payload.fetch("reason")).to eq("No disponible")
    expect(payload.fetch("recurrenceLabel")).to eq("Cada semana")

    delete admin_availability_block_path(block, format: :json), headers: browser_headers.merge("Accept" => "application/json")

    expect(response).to have_http_status(:ok)
    expect(block.reload).to be_cancelled
  end

  it "rejects calendar appointments assigned to a professional with an unavailable time block" do
    user, business = create_admin_with_business
    category = ServiceCategory.find_or_create_for!(business: business, name: "Estética", primary_category: true)
    service = business.services.create!(name: "Consulta", service_category: category, category: category.name, duration_minutes: 30, price_cents: 5_000_00, active: true)
    employee = business.employee_memberships.create!(
      name: "Juan Perez",
      first_name: "Juan",
      last_name: "Perez",
      email_address: "juan-#{SecureRandom.hex(4)}@example.com",
      status: "active"
    )
    starts_at = 2.days.from_now.change(hour: 19, min: 30, sec: 0)
    business.availability_blocks.create!(
      employee_membership: employee,
      starts_at: starts_at,
      ends_at: starts_at + 30.minutes,
      block_type: "professional_block",
      reason: "No disponible"
    )

    sign_in(user)
    expect {
      post admin_appointments_path(format: :json), params: {
        appointment: {
          service_id: service.id,
          employee_membership_id: employee.id,
          customer_name: "Sofía Gomez",
          customer_phone: "+54 9 11 7777-7777",
          customer_email: "sofia@example.com",
          starts_at: starts_at.iso8601,
          status: "confirmed"
        }
      }, headers: browser_headers.merge("Accept" => "application/json")
    }.not_to change { business.appointments.count }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch("errors").join(" ")).to include("no está disponible")
  end

  it "uses the team editor with service assignment for new and edit" do
    user, business = create_admin_with_business
    category = ServiceCategory.find_or_create_for!(business: business, name: "Estética", primary_category: true)
    service = business.services.create!(
      name: "Consulta estética",
      service_category: category,
      category: category.name,
      duration_minutes: 30,
      price_cents: 10_000_00,
      active: true
    )
    employee = business.employee_memberships.create!(
      first_name: "Ana",
      last_name: "Pérez",
      email_address: "ana-#{SecureRandom.hex(4)}@example.com",
      status: "active"
    )

    sign_in(user)
    get new_admin_employee_membership_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Datos personales")
    expect(response.body).to include("Servicios")
    expect(response.body).to include("Buscar servicios")
    expect(response.body).to include("Consulta estética")
    expect(response.body).not_to include("Sin sucursal fija")
    expect(response.body).not_to include("Sucursal")
    expect(response.body).to include(%(class="team-editor-topbar"))
    expect(response.body).to include(%(value="Guardar"))
    expect(response.body).to include(">Cerrar</a>")
    expect(response.body).not_to include(%(class="admin-shell-header))
    expect(response.body).not_to include(%(value="Enviar invitación"))

    get edit_admin_employee_membership_path(employee), headers: browser_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Editar miembro del equipo")

    patch admin_employee_membership_path(employee), params: {
      employee_membership: {
        first_name: employee.first_name,
        last_name: employee.last_name,
        phone: employee.phone,
        calendar_color: employee.calendar_color,
        service_ids: [ service.id.to_s ]
      }
    }, headers: browser_headers

    expect(response).to redirect_to(admin_employee_memberships_path)
    expect(employee.reload.service_ids).to eq([ service.id ])
  end

  it "creates a calendar appointment for the selected existing customer" do
    user, business = create_admin_with_business
    category = ServiceCategory.find_or_create_for!(business: business, name: "Estética", primary_category: true)
    service = business.services.create!(name: "Consulta", service_category: category, category: category.name, duration_minutes: 30, price_cents: 5_000_00, active: true)
    addon_service = business.services.create!(name: "Limpieza", service_category: category, category: category.name, duration_minutes: 45, price_cents: 3_000_00, active: true)
    customer = business.customer_profiles.create!(name: "Sofía Gomez", phone: "+54 9 11 7777-7777", email: "sofia@example.com")
    pet = customer.pets.create!(business: business, name: "Mora", breed: "Caniche", sex: "female")

    sign_in(user)
    request_headers = browser_headers.merge(
      "Accept" => "application/json",
      "X-Forwarded-Host" => "51d9-187-61-184-88.ngrok-free.app",
      "X-Forwarded-Proto" => "https"
    )
    post admin_appointments_path(format: :json), params: {
      appointment: {
        service_id: service.id,
        add_on_service_ids: [ addon_service.id ],
        customer_profile_id: customer.id,
        customer_name: "Nombre ignorado",
        pet_id: pet.id,
        starts_at: 2.days.from_now.change(hour: 10).iso8601,
        status: "confirmed"
      }
    }, headers: request_headers

    appointment = business.appointments.order(:created_at).last
    expect(response).to have_http_status(:created)
    expect(appointment.customer_profile).to eq(customer)
    expect(appointment.pet).to eq(pet)
    expect(appointment.customer_name).to eq("Sofía Gomez")
    expect(appointment.add_on_services).to contain_exactly(addon_service)
    expect(appointment.ends_at - appointment.starts_at).to eq(75.minutes)
    expect(appointment.final_price_cents).to eq(8_000_00)
    expect(response.parsed_body.fetch("services").pluck("name")).to eq([ "Consulta", "Limpieza" ])
    expect(response.parsed_body.fetch("customerProfileId")).to eq(customer.id.to_s)
    expect(response.parsed_body.fetch("customerProfileUrl")).to eq(
      edit_admin_customer_profile_path(
        customer,
        return_to: admin_calendar_path(date: appointment.starts_at.to_date.iso8601, t: appointment.short_uuid)
      )
    )
    expect(response.parsed_body.fetch("customerProfilePanelUrl")).to include("/admin/clientes/#{customer.id}/panel")
    expect(response.parsed_body.fetch("id")).to eq(appointment.short_uuid)
    expect(response.parsed_body).not_to have_key("customerMessageUrl")
    expect(response.parsed_body.fetch("customerEmail")).to eq("sofia@example.com")
    expect(response.parsed_body.fetch("petName")).to eq("Mora")
    expect(response.parsed_body.fetch("customerPortalUrl")).to start_with("https://51d9-187-61-184-88.ngrok-free.app/#{business.slug}/mis-turnos/")
    expect(response.parsed_body.fetch("customerCreatedAt")).to eq(customer.created_at.to_date.iso8601)
    expect(response.parsed_body.fetch("customerSummary")).to include(
      "appointmentsCount" => 1,
      "totalSales" => 8_000,
      "noShowCount" => 0,
      "statusLabel" => "Nuevo",
      "statusTone" => "green"
    )
    expect(response.parsed_body.fetch("depositAmount")).to eq(0)
    expect(response.parsed_body.fetch("remainingBalance")).to eq(8_000)
    expect(response.parsed_body.fetch("destroyUrl")).to eq(admin_destroy_appointment_path(appointment, format: :json))
    expect(response.parsed_body.fetch("cancelUrl")).to eq(cancel_admin_appointment_path(appointment, format: :json))

    expect {
      delete admin_destroy_appointment_path(appointment, format: :json), headers: browser_headers.merge("Accept" => "application/json")
    }.to change { business.appointments.where(id: appointment.id).count }.from(1).to(0)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("deleted")).to be(true)

    public_starts_at = 4.days.from_now.change(hour: 10)
    public_appointment = business.appointments.create!(
      service: service,
      customer_name: "Reserva pública",
      customer_phone: "+54 9 11 1111-2222",
      starts_at: public_starts_at,
      ends_at: public_starts_at + service.duration_minutes.minutes,
      source: :public_booking,
      status: :confirmed,
      deposit_status: "approved",
      deposit_amount_cents: 2_000_00,
      final_price_cents: service.price_cents
    )

    expect {
      delete admin_destroy_appointment_path(public_appointment, format: :json), headers: browser_headers.merge("Accept" => "application/json")
    }.not_to change { business.appointments.where(id: public_appointment.id).count }

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body.fetch("errors").join(" ")).to include("Solo se pueden eliminar turnos creados desde el calendario")

    get admin_calendar_path(date: public_starts_at.to_date.iso8601), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%("id":"#{public_appointment.short_uuid}"))
    expect(response.body).not_to include(%("id":"#{public_appointment.id}"))
    expect(response.body).to include(%("depositAmount":2000))
    expect(response.body).to include(%("remainingBalance":3000))
    expect(response.body).not_to include(admin_destroy_appointment_path(public_appointment, format: :json))

    expect {
      post admin_appointments_path(format: :json), params: {
        appointment: {
          service_id: service.id,
          create_customer_profile: true,
          customer_name: "Ferchu",
          customer_phone: "",
          starts_at: 3.days.from_now.change(hour: 11).iso8601,
          status: "confirmed"
        }
      }, headers: browser_headers.merge("Accept" => "application/json")
    }.not_to change { business.customer_profiles.where(name: "Ferchu").count }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch("errors")).not_to be_empty
  end

  it "cancels appointments from the calendar, records the actor and hides them from the schedule" do
    user, business = create_admin_with_business
    user.update!(name: "Julian Alvarez")
    customer = business.customer_profiles.create!(name: "Ada Lovelace", phone: "+54 9 11 3333-3333")
    service = business.services.create!(name: "Diseño y perfilado de cejas", slug: "diseno-#{SecureRandom.hex(4)}", duration_minutes: 30, price_cents: 14_000_00)
    starts_at = Time.zone.local(2026, 8, 4, 10)
    appointment = business.appointments.create!(
      service: service,
      customer_profile: customer,
      customer_name: customer.name,
      customer_phone: customer.phone,
      starts_at: starts_at,
      ends_at: starts_at + 30.minutes,
      status: :confirmed,
      final_price_cents: service.price_cents
    )

    sign_in(user)
    patch cancel_admin_appointment_path(appointment, format: :json),
      params: { reason: "El cliente pidió cancelar por teléfono." },
      headers: browser_headers.merge("Accept" => "application/json")

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("id" => appointment.short_uuid, "status" => "canceled")
    expect(appointment.reload).to have_attributes(
      status: "canceled",
      canceled_by: user.email_address,
      canceled_by_user: user,
      cancellation_reason: "El cliente pidió cancelar por teléfono."
    )
    expect(appointment.canceled_at).to be_present
    expect(appointment.booking_notes.find_by!(note_type: "cancellation").body).to eq("El cliente pidió cancelar por teléfono.")

    get admin_calendar_path(date: starts_at.to_date.iso8601), headers: browser_headers
    expect(response).to have_http_status(:ok)
    calendar_appointments = JSON.parse(response.body.match(/let appointments = (.+?);/)[1])
    expect(calendar_appointments).not_to include(include("id" => appointment.short_uuid))

    get edit_admin_customer_profile_path(customer), params: { section: "appointments" }, headers: browser_headers
    expect(response.body).to include("Cancelado por Julian Alvarez")
    expect(response.body).to include("El cliente pidió cancelar por teléfono.")
  end

  it "requires a cancellation reason when the center cancels an appointment" do
    user, business = create_admin_with_business
    service = business.services.create!(name: "Peinado", slug: "peinado-#{SecureRandom.hex(4)}", duration_minutes: 30, price_cents: 10_000_00)
    starts_at = 2.days.from_now.change(hour: 10, min: 0)
    appointment = business.appointments.create!(
      service: service,
      customer_name: "Ada Lovelace",
      customer_phone: "+54 9 11 3333-3333",
      starts_at: starts_at,
      ends_at: starts_at + 30.minutes,
      status: :confirmed,
      final_price_cents: service.price_cents
    )

    sign_in(user)

    expect {
      patch cancel_admin_appointment_path(appointment, format: :json),
        params: { reason: "   " },
        headers: browser_headers.merge("Accept" => "application/json")
    }.not_to change { appointment.reload.status }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch("errors")).to include("Indicá el motivo de la cancelación.")
  end

  it "renders waitlist data in the calendar and manages entries through calendar endpoints" do
    user, business = create_admin_with_business
    category = ServiceCategory.find_or_create_for!(business: business, name: "Estética", primary_category: true)
    service = business.services.create!(name: "Consulta", service_category: category, category: category.name, duration_minutes: 30, price_cents: 5_000_00, active: true)
    customer = business.customer_profiles.create!(name: "Camila Gomez", phone: "+54 9 11 2222-2222", email: "camila@example.com")
    desired_date = 2.days.from_now.to_date
    entry = business.waitlist_entries.create!(
      service: service,
      client_name: "Julieta Perez",
      client_phone: "+54 9 11 1111-1111",
      email: "julieta@example.com",
      desired_date: desired_date,
      preferred_time_windows: [ WaitlistEntry.normalize_time_window("morning") ],
      source: "public_page",
      status: "waiting"
    )

    sign_in(user)
    get admin_calendar_path(waitlist: "1", service_id: service.id, desired_date: desired_date.iso8601), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(id="waitlistToolbarButton"))
    expect(response.body).to include("openWaitlistPanel")
    expect(response.body).to include("Lista de espera")
    expect(response.body).to include("Julieta Perez")
    expect(response.body).to include("Consulta")
    expect(response.body).to include("Mañana")

    expect {
      post admin_waitlist_entries_path(format: :json), params: {
        waitlist_entry: {
          customer_profile_id: customer.id,
          service_id: service.id,
          desired_date: desired_date.iso8601,
          preferred_time_windows: [ { period: "night", label: "Noche", start_time: "18:00", end_time: "23:55" } ],
          notes: "Prefiere después de las 18"
        }
      }, headers: browser_headers.merge("Accept" => "application/json")
    }.to change { business.waitlist_entries.count }.by(1)

    created_entry = business.waitlist_entries.order(:created_at).last
    expect(response).to have_http_status(:created)
    expect(response.parsed_body.fetch("clientName")).to eq("Camila Gomez")
    expect(response.parsed_body.fetch("preferredTimeLabels")).to eq([ "Noche" ])
    expect(created_entry.customer_profile).to eq(customer)

    patch admin_waitlist_entry_path(entry, format: :json), params: {
      waitlist_entry: {
        customer_profile_id: entry.customer_profile_id,
        client_name: entry.client_name,
        client_phone: entry.client_phone,
        email: entry.email,
        service_id: service.id,
        desired_date: (desired_date + 1.day).iso8601,
        preferred_time_windows: [ { period: "afternoon", label: "Tarde", start_time: "12:00", end_time: "18:00" } ]
      }
    }, headers: browser_headers.merge("Accept" => "application/json")

    expect(response).to have_http_status(:ok)
    expect(entry.reload.desired_date).to eq(desired_date + 1.day)
    expect(response.parsed_body.fetch("preferredTimeLabels")).to eq([ "Tarde" ])

    delete admin_waitlist_entry_path(entry, format: :json), headers: browser_headers.merge("Accept" => "application/json")

    expect(response).to have_http_status(:ok)
    expect(entry.reload).to be_dismissed
  end

  it "redirects the old waitlist page to the calendar drawer entry point" do
    get "/admin/lista-de-espera", headers: browser_headers

    expect(response).to redirect_to("/admin/calendario?waitlist=1")
  end

  it "stores the complete website design selected in settings" do
    user, business = create_admin_with_business
    sign_in(user)

    patch admin_settings_path, params: {
      settings_tab: "diseno-web",
      business_account: {
        business_name: business.name,
        owner_name: user.name.presence || business.name,
        owner_email: user.email_address,
        contact_phone: business.contact_phone,
        slug: business.slug,
        public_site_mode: "full_website",
        public_custom_html: '<section class="ht-section ht-about"><h2>Quiénes somos</h2></section>',
        public_category_custom_html: '<section><h1>{{category_name}}</h1><div data-dog-grooming-slot="services"></div></section>'
      }
    }, headers: browser_headers

    expect(response).to redirect_to(admin_settings_path(settings_tab: "diseno-web", anchor: "diseno-web"))
    expect(business.reload).to have_attributes(
      public_site_mode: "full_website",
      public_custom_html: '<section class="ht-section ht-about"><h2>Quiénes somos</h2></section>',
      public_category_custom_html: '<section><h1>{{category_name}}</h1><div data-dog-grooming-slot="services"></div></section>'
    )

    get admin_settings_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    expect(document.at_css("[data-web-design-navigation]")["hidden"]).to be_nil
    expect(document.at_css("#diseno-web")).to be_present
    expect(document.at_css("#business_account_public_custom_html").text).to include("Quiénes somos")
    expect(document.at_css("#business_account_public_category_custom_html").text).to include("{{category_name}}")
    expect(document.at_css("[data-public-custom-html-preview]")["sandbox"]).to eq("")
    expect(document.at_css("[data-public-category-custom-html-preview]")["sandbox"]).to eq("")
    expect(document.at_css("#business_account_public_custom_css")).to be_nil
    expect(document.css('input[name="business_account[public_template]"]')).to be_empty
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
      email_address: "admin-shell-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )
    business = Business.create!(
      owner: user,
      name: "Aura Estética",
      slug: "aura-estetica-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 4444-4444",
      onboarding_completed_at: Time.current
    )

    [ user, business ]
  end
end
