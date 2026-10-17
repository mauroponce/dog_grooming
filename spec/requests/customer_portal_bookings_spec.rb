require "rails_helper"

RSpec.describe "Customer portal bookings", type: :request do
  before { host! "localhost" }

  it "generates and renders a short booking URL" do
    business = create_business
    appointment = create_appointment(business)

    expect(appointment.customer_portal_booking_token.length).to eq(16)
    expect(appointment.customer_portal_booking_url).to include("/#{business.slug}/turno/#{appointment.customer_portal_booking_token}")
    expect(appointment.customer_portal_booking_url).not_to include("/mis-turnos/reserva/")

    get customer_portal_short_booking_path(business.slug, appointment.customer_portal_booking_token), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(appointment.service.name)
    expect(response.body).to include(appointment.customer_name)
  end

  it "shows the Google Calendar action only for Gmail customers" do
    business = create_business
    gmail_customer = business.customer_profiles.create!(
      name: "Julieta Perez",
      phone: "+54 9 11 1111-1111",
      email: "julieta@gmail.com"
    )
    gmail_appointment = create_appointment(business, customer_profile: gmail_customer)

    get customer_portal_short_booking_path(business.slug, gmail_appointment.customer_portal_booking_token), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Agregar a Google Calendar")
    expect(response.body).to include("Gestionar mis turnos")
    expect(response.body).to include("calendar.google.com/calendar/u/0/r/eventedit")
    expect(response.body).to include(customer_portal_entry_path(business.slug))
    expect(response.body).not_to include(gmail_customer.customer_portal_short_token, gmail_customer.customer_portal_token)
    expect(response.body).not_to include("Pedir reprogramación")
    expect(response.body).not_to include("Consultar por teléfono")

    non_gmail_customer = business.customer_profiles.create!(
      name: "Camila Ruiz",
      phone: "+54 9 11 2222-2222",
      email: "camila@example.com"
    )
    non_gmail_appointment = create_appointment(business, customer_profile: non_gmail_customer, starts_at: 4.days.from_now.change(hour: 11, min: 0, sec: 0))

    get customer_portal_short_booking_path(business.slug, non_gmail_appointment.customer_portal_booking_token), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Agregar a Google Calendar")
    expect(response.body).not_to include("calendar.google.com")
    expect(response.body).to include("Gestionar mis turnos")
  end

  it "opens the customer dashboard from the short customer portal token" do
    business = create_business
    customer = business.customer_profiles.create!(
      name: "Julieta Perez",
      phone: "+54 9 11 1111-1111",
      email: "julieta@example.com"
    )
    appointment = create_appointment(business, customer_profile: customer)

    expect(customer.customer_portal_short_token.length).to eq(12)
    expect(customer.customer_portal_url).to include("/#{business.slug}/mis-turnos/#{customer.customer_portal_short_token}")
    expect(customer.customer_portal_url).not_to include(customer.customer_portal_token)

    get customer_portal_profile_access_path(business.slug, customer.customer_portal_short_token), headers: browser_headers

    expect(response).to redirect_to(customer_portal_dashboard_path(business.slug))

    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Próximos turnos")
    expect(response.body).to include(appointment.service.name)
    expect(response.body).to include("Reprogramación online hasta 24 horas antes.")
    expect(response.body).to include("La seña no se devuelve por cancelación.")
    expect(response.body).to include("La seña no se devuelve automáticamente por cancelación.")
    expect(response.body).to include("google.com/maps/dir")
    expect(response.body).to include(business.public_url)
    expect(response.body).to include("Reprogramar")
    expect(response.body).to include("Cancelar turno")
    expect(response.body).to include("Sin seña")
    expect(response.body).to include("Resta pagar en el local: $15.000")
    expect(response.body).not_to include("Reserva protegida")
    expect(response.body).not_to include("Ver detalle")
    expect(response.body).not_to include("Cómo llegar")
    expect(response.body).not_to include("Visitas realizadas")
    expect(response.body).not_to include('data-tab="loyalty"')
    expect(response.body).not_to include("Programa de fidelidad")
  end

  it "hides the assigned professional and shows the deposit and local balance when professional selection is disabled" do
    business = create_business
    customer = business.customer_profiles.create!(
      name: "Julieta Perez",
      phone: "+54 9 11 1111-1111",
      email: "julieta@example.com"
    )
    professional = business.employee_memberships.create!(
      name: "Gloria Principal",
      first_name: "Gloria",
      last_name: "Principal",
      email_address: "gloria-#{SecureRandom.hex(4)}@example.com",
      status: "active",
      can_receive_appointments: true
    )
    appointment = create_appointment(business, customer_profile: customer, employee_membership: professional)
    appointment.service.update!(duration_minutes: 60, price_cents: 10_000_00)
    appointment.update!(
      employee_membership: professional,
      deposit_status: "approved",
      deposit_amount_cents: 3_000_00,
      payment_collection_method: "manual_proof"
    )
    mercado_pago_appointment = create_appointment(
      business,
      customer_profile: customer,
      starts_at: 4.days.from_now.change(hour: 11, min: 0, sec: 0),
      employee_membership: professional
    )
    mercado_pago_appointment.service.update!(price_cents: 10_000_00)
    mercado_pago_appointment.update!(
      deposit_status: "approved",
      deposit_amount_cents: 4_000_00,
      payment_collection_method: "mercado_pago"
    )

    get customer_portal_profile_access_path(business.slug, customer.customer_portal_short_token), headers: browser_headers
    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Duración: 1 hora")
    expect(response.body).not_to include("Gloria Principal")
    expect(response.body).to include("Seña pagada por transferencia: $3.000")
    expect(response.body).to include("Seña pagada por Mercado Pago: $4.000")
    expect(response.body).to include("Resta pagar en el local: $7.000")
    expect(response.body).to include("Resta pagar en el local: $6.000")

    get customer_portal_short_booking_path(business.slug, appointment.customer_portal_booking_token), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Gloria Principal")
  end

  it "keeps the legacy customer portal token valid" do
    business = create_business
    customer = business.customer_profiles.create!(
      name: "Julieta Perez",
      phone: "+54 9 11 1111-1111",
      email: "julieta@example.com"
    )

    get customer_portal_profile_access_path(business.slug, customer.customer_portal_token), headers: browser_headers

    expect(response).to redirect_to(customer_portal_dashboard_path(business.slug))
  end

  it "updates the customer profile from the private dashboard" do
    business = create_business
    customer = business.customer_profiles.create!(
      name: "Julieta Perez",
      first_name: "Julieta",
      last_name: "Perez",
      phone: "+54 9 11 1111-1111",
      email: "julieta@example.com"
    )

    get customer_portal_profile_access_path(business.slug, customer.customer_portal_short_token), headers: browser_headers

    patch customer_portal_dashboard_update_path(business.slug), params: {
      customer_profile: {
        first_name: "Juli",
        last_name: "Pérez",
        phone: "+54 9 11 3333-3333",
        email: "juli@example.com"
      }
    }, headers: browser_headers

    expect(response).to redirect_to(customer_portal_dashboard_path(business.slug, anchor: "profile"))
    expect(customer.reload.name).to eq("Juli Pérez")
    expect(customer.phone).to eq("+54 9 11 3333-3333")
    expect(customer.normalized_phone).to eq(PhoneNumber.normalize("+54 9 11 3333-3333"))
    expect(customer.email).to eq("juli@example.com")
    expect(customer.normalized_email).to eq("juli@example.com")
  end

  it "lets the customer cancel an upcoming appointment from the portal" do
    business = create_business
    customer = business.customer_profiles.create!(
      name: "Julieta Perez",
      phone: "+54 9 11 1111-1111",
      email: "julieta@example.com"
    )
    appointment = create_appointment(business, customer_profile: customer)

    expect {
      post customer_portal_booking_cancel_path(business.slug, appointment.customer_portal_booking_token), params: {
        cancellation_reason: "No puedo asistir"
      }, headers: browser_headers
    }.to change { business.provider_events.where(event_type: "customer_cancelled_booking").count }.by(1)

    expect(response).to redirect_to(customer_portal_dashboard_path(business.slug))
    expect(appointment.reload).to be_canceled
    expect(appointment.cancellation_reason).to eq("No puedo asistir")
    expect(business.provider_events.last.metadata["appointment_id"]).to eq(appointment.id)
  end

  it "lets the customer reschedule an upcoming appointment into an available slot" do
    business = create_business
    customer = business.customer_profiles.create!(
      name: "Julieta Perez",
      phone: "+54 9 11 1111-1111",
      email: "julieta@example.com"
    )
    appointment = create_appointment(business, customer_profile: customer)
    first_professional = business.employee_memberships.create!(
      name: "Ana Primera",
      first_name: "Ana",
      last_name: "Primera",
      email_address: "ana-#{SecureRandom.hex(4)}@example.com",
      status: "active",
      can_receive_appointments: true,
      sort_order: 1
    )
    second_professional = business.employee_memberships.create!(
      name: "Brenda Segunda",
      first_name: "Brenda",
      last_name: "Segunda",
      email_address: "brenda-#{SecureRandom.hex(4)}@example.com",
      status: "active",
      can_receive_appointments: true,
      sort_order: 2
    )
    appointment.service.employee_memberships << first_professional << second_professional
    next_starts_at = appointment.starts_at.change(hour: 11, min: 0)

    post customer_portal_booking_reschedule_path(business.slug, appointment.customer_portal_booking_token), params: {
      starts_at: next_starts_at.iso8601
    }, headers: browser_headers

    expect(response).to redirect_to(customer_portal_dashboard_path(business.slug))
    expect(appointment.reload.starts_at.to_i).to eq(next_starts_at.to_i)
    expect(appointment.ends_at.to_i).to eq((next_starts_at + appointment.service.duration_minutes.minutes).to_i)
    expect(appointment.employee_membership).to eq(first_professional)
      expect(appointment.internal_notes).to include("Reprogramado desde portal de cliente")
  end

  it "returns only public-booking availability when choosing a new date and time" do
    business = create_business
    customer = business.customer_profiles.create!(
      name: "Julieta Perez",
      phone: "+54 9 11 1111-1111",
      email: "julieta@example.com"
    )
    appointment = create_appointment(business, customer_profile: customer)
    date = appointment.starts_at.to_date

    get customer_portal_booking_reschedule_availability_path(business.slug, appointment.customer_portal_booking_token), params: {
      date_window_start: date.iso8601,
      date: date.iso8601
    }, as: :json, headers: browser_headers

    payload = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(payload.fetch("selectedDate")).to eq(date.iso8601)
    expect(payload.fetch("dates")).to include(a_hash_including("date" => date.iso8601, "available" => true))
    expect(payload.fetch("slots").map { |slot| slot.fetch("time") }).to include("11:00")
    expect(payload.fetch("slots").map { |slot| slot.fetch("startsAt") }).not_to include(appointment.starts_at.iso8601)
  end

  def create_business
    owner = User.create!(
      email_address: "portal-owner-#{SecureRandom.hex(4)}@example.com",
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

  def create_appointment(business, customer_profile: nil, starts_at: 3.days.from_now.change(hour: 10, min: 0, sec: 0), employee_membership: nil)
    business.availability_rules.find_by!(weekday: starts_at.wday).update!(active: true, start_time: "09:00", end_time: "19:00")
    service = business.services.create!(
      name: "Esmaltado",
      slug: "esmaltado-#{SecureRandom.hex(3)}",
      category: "Beauty Nails",
      description: "Esmaltado tradicional.",
      duration_minutes: 30,
      price_cents: 15_000_00,
      active: true,
      public_visible: true,
      visibility_mode: "public"
    )

    business.appointments.create!(
      service: service,
      customer_profile: customer_profile,
      customer_name: "Julieta Perez",
      customer_phone: "+54 9 11 1111-1111",
      employee_membership: employee_membership,
      starts_at: starts_at,
      status: :confirmed,
      source: :public_booking,
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )
  end

  def browser_headers
    {
      "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36",
      "HTTP_USER_AGENT" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"
    }
  end
end
