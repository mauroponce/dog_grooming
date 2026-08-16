require "rails_helper"

RSpec.describe "Admin home", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before { host! "localhost" }

  it "renders the admin home with business metrics and operational actions" do
    travel_to Time.zone.local(2026, 7, 25, 10, 0, 0) do
      user, business = create_admin_with_business
      employee = create_employee(business)
      service = create_service(business)
      appointment_start = Time.zone.local(2026, 7, 25, 16, 0, 0)
      today = appointment_start.to_date

      business.availability_rules.find_or_initialize_by(weekday: today.wday).update!(
        active: true,
        start_time: "00:00",
        end_time: "23:59"
      )

      business.appointments.create!(
        service: service,
        employee_membership: employee,
        customer_name: "Valentina Gómez",
        starts_at: appointment_start,
        ends_at: appointment_start + 30.minutes,
        status: :confirmed,
        source: :manual,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )

      sign_in(user)
      get admin_home_path, headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Buen día")
      expect(response.body).to include("Resumen de Cita.pet IA")
      expect(response.body).to include("Oportunidades para hoy")
      expect(response.body).to include("Valor potencial de los espacios")
      expect(response.body).to include("Próximos turnos")
      expect(response.body).to include("Valentina Gómez")
      expect(response.body).not_to include("Necesita tu atención")
      expect(response.body).not_to include("Ver oportunidad")
      expect(response.body).not_to include("Oportunidad abierta")
      expect(response.body).not_to include("Accesos rápidos")
      expect(response.body).not_to include("Disponibilidad restante hoy")
      expect(response.body).to include("Asistente diario")
      expect(response.body).to include('channel="Turbo::StreamsChannel"')
      expect(response.body).to include("admin_appointments")
    end
  end

  it "uses the home page as the admin root" do
    user, = create_admin_with_business

    sign_in(user)
    get admin_root_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Buen día")
    expect(response.body).to include("Próximos turnos")
    expect(response.body).not_to include("Accesos rápidos")
  end

  it "opens calendar navigation outside the upcoming appointments frame" do
    user, = create_admin_with_business

    sign_in(user)
    get admin_home_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    upcoming_frame = document.at_css("turbo-frame#home_upcoming_appointments")
    calendar_link = upcoming_frame.css("a").find { |link| link.text.squish == "Abrir calendario" }

    expect(response).to have_http_status(:ok)
    expect(calendar_link).to be_present
    expect(calendar_link["data-turbo-frame"]).to eq("_top")
  end

  it "shows ten upcoming appointments per page and paginates the rest in the home frame" do
    travel_to Time.zone.local(2026, 8, 10, 9, 0, 0) do
      user, business = create_admin_with_business
      employee = create_employee(business)
      service = create_service(business)

      11.times do |index|
        starts_at = Time.zone.local(2026, 8, 11, 9, 0, 0) + index.hours
        business.appointments.create!(
          service: service,
          employee_membership: employee,
          customer_name: "Cliente #{index + 1}",
          starts_at: starts_at,
          ends_at: starts_at + 30.minutes,
          status: :confirmed,
          source: :manual,
          base_price_cents: service.price_cents,
          final_price_cents: service.price_cents
        )
      end

      sign_in(user)
      get admin_home_path, headers: browser_headers

      document = Nokogiri::HTML(response.body)
      expect(response).to have_http_status(:ok)
      upcoming_frame = document.at_css("turbo-frame#home_upcoming_appointments")
      expect(upcoming_frame).to be_present
      expect(upcoming_frame["autoscroll"]).to eq("false")
      expect(response.body).to include("data-customers-results-loader-preserve-scroll-value=\"true\"")
      expect(document.css("[data-home-appointments-details-url]").size).to eq(10)
      expect(response.body).to include("upcoming_page=2")

      get admin_home_path(upcoming_page: 2), headers: browser_headers

      document = Nokogiri::HTML(response.body)
      expect(document.css("[data-home-appointments-details-url]").size).to eq(1)
      expect(document.at_css("[data-home-appointments-details-url]").text).to include("Cliente 11")
    end
  end

  it "returns the appointment payload used by the home detail drawer" do
    travel_to Time.zone.local(2026, 8, 10, 9, 0, 0) do
      user, business = create_admin_with_business
      employee = create_employee(business)
      service = create_service(business)
      appointment = business.appointments.create!(
        service: service,
        employee_membership: employee,
        customer_name: "Noelia Romero",
        customer_phone: "+54 9 11 4444-4444",
        starts_at: Time.zone.local(2026, 8, 11, 11, 0, 0),
        ends_at: Time.zone.local(2026, 8, 11, 12, 0, 0),
        status: :confirmed,
        source: :manual,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )

      sign_in(user)
      get admin_appointment_details_path(appointment, format: :json), headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "id" => appointment.short_uuid,
        "client" => "Noelia Romero",
        "employeeName" => employee.display_name,
        "sourceLabel" => "Manual",
        "totalPrice" => service.price_cents / 100,
        "depositStatusLabel" => "Sin seña",
        "cancelUrl" => cancel_admin_appointment_path(appointment, format: :json)
      )
      expect(response.parsed_body.fetch("endsAt")).to eq(appointment.ends_at.iso8601)
      expect(response.parsed_body.fetch("createdAt")).to be_present
      expect(response.parsed_body).not_to have_key("detailVariant")

      get admin_appointment_details_path(appointment, format: :json, context: "customer_profile"), headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("detailVariant")).to eq("customer-profile")
    end
  end

  it "records the remaining balance from the detail drawer and returns its payment data" do
    travel_to Time.zone.local(2026, 8, 10, 9, 0, 0) do
      user, business = create_admin_with_business
      employee = create_employee(business)
      service = create_service(business)
      appointment = business.appointments.create!(
        service: service,
        employee_membership: employee,
        customer_name: "Noelia Romero",
        customer_phone: "+54 9 11 4444-4444",
        starts_at: Time.zone.local(2026, 8, 11, 11, 0, 0),
        ends_at: Time.zone.local(2026, 8, 11, 12, 0, 0),
        status: :confirmed,
        source: :manual,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )

      sign_in(user)
      patch mark_remaining_balance_paid_admin_appointment_path(appointment, format: :json), headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "remainingBalance" => 0,
        "remainingBalancePaidAmount" => service.price_cents / 100,
        "remainingBalancePaymentMethod" => "Transferencia manual"
      )
      expect(response.parsed_body.fetch("remainingBalancePaidAt")).to be_present
      expect(response.parsed_body).not_to have_key("markRemainingBalancePaidUrl")
      expect(appointment.reload.remaining_balance_paid_by).to eq(user)

      patch mark_remaining_balance_paid_admin_appointment_path(appointment, format: :json), headers: browser_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.fetch("errors")).to include("El turno no tiene saldo pendiente para registrar.")
    end
  end

  it "exposes a submitted deposit for approval and confirms it from the detail drawer" do
    travel_to Time.zone.local(2026, 8, 10, 9, 0, 0) do
      user, business = create_admin_with_business
      employee = create_employee(business)
      service = create_service(business)
      appointment = business.appointments.create!(
        service: service,
        employee_membership: employee,
        customer_name: "Noelia Romero",
        customer_phone: "+54 9 11 4444-4444",
        starts_at: Time.zone.local(2026, 8, 11, 11, 0, 0),
        ends_at: Time.zone.local(2026, 8, 11, 12, 0, 0),
        status: :pending_deposit_review,
        source: :public_booking,
        deposit_status: "submitted",
        deposit_submitted_at: Time.current,
        deposit_amount_cents: 2_000_00,
        payment_collection_method: "manual_proof",
        payment_charge_mode: "deposit",
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )
      appointment.deposit_receipt.attach(
        io: StringIO.new("receipt image"),
        filename: "comprobante.png",
        content_type: "image/png"
      )

      sign_in(user)
      get admin_appointment_details_path(appointment, format: :json), headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "status" => "pending_deposit_review",
        "statusLabel" => "Seña pendiente de aprobación",
        "color" => "#fef3c7",
        "approveDepositUrl" => approve_deposit_admin_appointment_path(appointment, format: :json),
        "rejectDepositUrl" => reject_deposit_admin_appointment_path(appointment, format: :json)
      )
      expect(response.parsed_body.fetch("depositReceiptPreviewUrl")).to be_present
      expect(response.parsed_body).not_to have_key("cancelUrl")

      patch approve_deposit_admin_appointment_path(appointment, format: :json), headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "status" => "confirmed",
        "statusLabel" => "Confirmado",
        "color" => "#d1fae5"
      )
      expect(appointment.reload).to be_confirmed
      expect(business.provider_events.find_by!(event_type: "new_booking").metadata.fetch("appointment_id")).to eq(appointment.id)
    end
  end

  it "lists service professionals and changes the assigned professional from the detail drawer" do
    travel_to Time.zone.local(2026, 8, 10, 9, 0, 0) do
      user, business = create_admin_with_business
      first_professional = create_employee(business)
      second_professional = business.employee_memberships.create!(
        first_name: "Juan",
        last_name: "Pérez",
        name: "Juan Pérez",
        email_address: "juan-#{SecureRandom.hex(4)}@example.com",
        specialty: "Manicuría",
        status: "active"
      )
      service = create_service(business)
      appointment = business.appointments.create!(
        service: service,
        employee_membership: first_professional,
        customer_name: "Noelia Romero",
        customer_phone: "+54 9 11 4444-4444",
        starts_at: Time.zone.local(2026, 8, 11, 11, 0, 0),
        ends_at: Time.zone.local(2026, 8, 11, 12, 0, 0),
        status: :confirmed,
        source: :manual,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )

      sign_in(user)
      get admin_appointment_details_path(appointment, format: :json), headers: browser_headers

      expect(response.parsed_body).to include(
        "availableProfessionalsUrl" => available_professionals_admin_appointment_path(appointment, format: :json),
        "changeProfessionalUrl" => change_professional_admin_appointment_path(appointment, format: :json)
      )

      get available_professionals_admin_appointment_path(appointment, format: :json), headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("professionals").pluck("id")).to contain_exactly(first_professional.id.to_s, second_professional.id.to_s)

      patch change_professional_admin_appointment_path(appointment, format: :json),
        params: { employee_membership_id: second_professional.id },
        headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "employeeId" => second_professional.id.to_s,
        "employeeName" => second_professional.display_name
      )
      expect(appointment.reload.employee_membership).to eq(second_professional)
    end
  end

  it "does not expose cancellation for an appointment whose start time has passed" do
    travel_to Time.zone.local(2026, 8, 10, 12, 0, 0) do
      user, business = create_admin_with_business
      employee = create_employee(business)
      service = create_service(business)
      appointment = business.appointments.create!(
        service: service,
        employee_membership: employee,
        customer_name: "Valentina Gómez",
        customer_phone: "+54 9 11 4444-4444",
        starts_at: Time.zone.local(2026, 8, 10, 11, 0, 0),
        ends_at: Time.zone.local(2026, 8, 10, 11, 30, 0),
        status: :confirmed,
        source: :manual,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )

      sign_in(user)
      get admin_appointment_details_path(appointment, format: :json), headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).not_to have_key("cancelUrl")

      get admin_calendar_path(date: appointment.starts_at.to_date.iso8601), headers: browser_headers

      calendar_appointments = JSON.parse(response.body.match(/let appointments = (.+?);/)[1])
      calendar_appointment = calendar_appointments.find { |item| item.fetch("id") == appointment.short_uuid }
      expect(calendar_appointment).not_to have_key("cancelUrl")
      expect(calendar_appointment).to include("status" => "completed", "statusLabel" => "Finalizado")

      get admin_appointment_details_path(appointment, format: :json), headers: browser_headers

      expect(response.parsed_body).to include("status" => "completed", "statusLabel" => "Finalizado")
      expect(response.parsed_body).not_to have_key("changeProfessionalUrl")
      expect(response.parsed_body).not_to have_key("cancelUrl")
      expect(response.parsed_body).not_to have_key("markRemainingBalancePaidUrl")
    end
  end

  it "returns editable internal notes separately from customer comments" do
    user, business = create_admin_with_business
    service = create_service(business)
    appointment = business.appointments.create!(
      service: service,
      customer_name: "Noelia Romero",
      customer_phone: "+54 9 11 4444-4444",
      starts_at: 2.days.from_now.change(hour: 11),
      ends_at: 2.days.from_now.change(hour: 12),
      status: :confirmed,
      source: :public_booking,
      customer_notes: "Tengo piel sensible.",
      internal_notes: "Usar producto hipoalergénico.",
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )

    sign_in(user)
    get admin_appointment_details_path(appointment, format: :json), headers: browser_headers

    expect(response.parsed_body).to include(
      "customerComment" => "Tengo piel sensible.",
      "internalNotes" => "Usar producto hipoalergénico.",
      "notesUrl" => update_notes_admin_appointment_path(appointment, format: :json)
    )

    patch update_notes_admin_appointment_path(appointment, format: :json),
      params: { appointment: { internal_notes: "Confirmar tolerancia antes de aplicar." } },
      headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("internalNotes" => "Confirmar tolerancia antes de aplicar.")
    expect(appointment.reload).to have_attributes(
      internal_notes: "Confirmar tolerancia antes de aplicar.",
      customer_notes: "Tengo piel sensible."
    )
  end

  it "shows nearby free time as manual availability instead of a false sales opportunity" do
    travel_to Time.zone.local(2026, 8, 4, 10, 0, 0) do
      user, business = create_admin_with_business
      employee = create_employee(business)
      create_service(business)

      business.availability_rules.find_or_initialize_by(weekday: Time.zone.today.wday).update!(
        active: true,
        start_time: "10:00",
        end_time: "10:45"
      )
      employee.ensure_availability_rules!
      employee.employee_availability_rules.find_by!(weekday: Time.zone.today.wday).update!(
        active: true,
        inherits_business_hours: true
      )

      sign_in(user)
      get admin_home_path, headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Quedan huecos libres, pero ya no dan tiempo para ofrecerlos")
      expect(response.body).to include("30 minutos disponibles")
      expect(response.body).to include("Próximo hueco")
      expect(response.body).to include("10:15")
      expect(response.body).to include("Abrir calendario")
      expect(response.body).not_to include("Disponibilidad restante hoy")
      expect(response.body).not_to include("Estos son los espacios que todavía podés convertir en reservas hoy")
    end
  end

  it "keeps suggested customers out of the home page" do
    travel_to Time.zone.local(2026, 8, 4, 9, 0, 0) do
      user, business = create_admin_with_business
      employee = create_employee(business)
      service = create_service(business)
      customer = business.customer_profiles.create!(
        first_name: "Julieta",
        last_name: "Martínez",
        name: "Julieta Martínez",
        phone: "+54 9 11 2222-3333"
      )

      business.availability_rules.find_or_initialize_by(weekday: Time.zone.today.wday).update!(
        active: true,
        start_time: "10:00",
        end_time: "11:00"
      )
      employee.ensure_availability_rules!
      employee.employee_availability_rules.find_by!(weekday: Time.zone.today.wday).update!(
        active: true,
        inherits_business_hours: true
      )
      business.waitlist_entries.create!(
        customer_profile: customer,
        service: service,
        client_name: customer.name,
        client_phone: customer.phone,
        desired_date: Time.zone.today,
        source: "public_page",
        status: "waiting"
      )

      sign_in(user)
      get admin_home_path, headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tenés 1 espacio que todavía podrías llenar")
      expect(response.body).not_to include("Agenda disponible")
      expect(response.body).not_to include("Ver oportunidad")
      expect(response.body).not_to include("Oportunidad abierta")
      expect(response.body).not_to include("Clientes compatibles")
      expect(response.body).not_to include("data-admin-home-open-opportunity")
      expect(response.body).not_to include("Sin tiempo suficiente para ofrecer hoy")
    end
  end

  it "shows a daily summary instead of claiming the agenda is full after business hours" do
    travel_to Time.zone.local(2026, 8, 4, 21, 0, 0) do
      user, business = create_admin_with_business
      employee = create_employee(business)
      service = create_service(business)
      business.availability_rules.find_by!(weekday: Time.zone.today.wday).update!(active: true, start_time: "10:00", end_time: "19:00")

      [ 10, 11, 12 ].each do |hour|
        business.appointments.create!(
          service: service,
          employee_membership: employee,
          customer_name: "Cliente #{hour}",
          starts_at: Time.zone.local(2026, 8, 4, hour, 0, 0),
          ends_at: Time.zone.local(2026, 8, 4, hour, 30, 0),
          status: :confirmed,
          source: :manual,
          base_price_cents: service.price_cents,
          final_price_cents: service.price_cents
        )
      end

      sign_in(user)
      get admin_home_path, headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("La jornada de hoy terminó")
      expect(response.body).to include("Turnos de hoy")
      expect(response.body).to include("3 turnos")
      expect(response.body).not_to include("La agenda de hoy está completa")
    end
  end

  it "shows the next ten future appointments across upcoming days" do
    travel_to Time.zone.local(2026, 7, 25, 10, 0, 0) do
      user, business = create_admin_with_business
      employee = create_employee(business)
      service = create_service(business)

      business.appointments.create!(
        service: service,
        employee_membership: employee,
        customer_name: "Turno pasado",
        starts_at: Time.zone.local(2026, 7, 25, 9, 0, 0),
        ends_at: Time.zone.local(2026, 7, 25, 9, 30, 0),
        status: :confirmed,
        source: :manual,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )

      11.times do |index|
        starts_at = Time.zone.local(2026, 7, 26, 10 + index, 0, 0)
        business.appointments.create!(
          service: service,
          employee_membership: employee,
          customer_name: "Cliente futuro #{index + 1}",
          starts_at: starts_at,
          ends_at: starts_at + 30.minutes,
          status: :confirmed,
          source: :manual,
          base_price_cents: service.price_cents,
          final_price_cents: service.price_cents
        )
      end

      sign_in(user)
      get admin_home_path, headers: browser_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Los próximos turnos agendados.")
      expect(response.body).to include("Mañana")
      expect(response.body).to include("Cliente: Cliente futuro 1")
      expect(response.body).to include("Jennifer López")
      expect(response.body).to include("Esmaltado")
      expect(response.body).to include("Cliente futuro 10")
      expect(response.body).not_to include("Cliente futuro 11")
      expect(response.body).not_to include("Turno pasado")
    end
  end

  it "registers contacted customers from a home opportunity" do
    travel_to Time.zone.local(2026, 7, 25, 12, 0, 0) do
      user, business = create_admin_with_business
      employee = create_employee(business)
      service = create_service(business)
      customer = business.customer_profiles.create!(
        first_name: "Julieta",
        last_name: "Martínez",
        name: "Julieta Martínez",
        phone: "+54 9 11 2222-3333"
      )

      sign_in(user)
      post admin_home_opportunity_contacts_path,
        params: {
          items: [
            {
              customer_profile_id: customer.id,
              service_id: service.id,
              employee_membership_id: employee.id,
              source: "follow_up",
              starts_at: Time.zone.local(2026, 7, 25, 16, 0, 0).iso8601,
              ends_at: Time.zone.local(2026, 7, 25, 17, 0, 0).iso8601,
              message: "Hola Julieta, tenemos un horario disponible.",
              result: "sent"
            }
          ]
        },
        as: :json,
        headers: browser_headers

      expect(response).to have_http_status(:ok)
      opportunity = business.sales_opportunities.last
      expect(opportunity.customer_profile).to eq(customer)
      expect(opportunity.service).to eq(service)
      expect(opportunity.employee_membership).to eq(employee)
      expect(opportunity).to be_contacted
      expect(opportunity.contacted_at).to be_present
      expect(opportunity.metadata).to include("source" => "follow_up", "result" => "sent")
    end
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

    def create_admin_with_business
      user = User.create!(
        email_address: "admin-home-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :admin
      )
      business = Business.create!(
        owner: user,
        name: "Estética Burzaco",
        slug: "estetica-burzaco-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-5555",
        onboarding_completed_at: Time.current
      )

      [ user, business ]
    end

    def create_employee(business)
      business.employee_memberships.create!(
        first_name: "Jennifer",
        last_name: "López",
        name: "Jennifer López",
        email_address: "jennifer-#{SecureRandom.hex(4)}@example.com",
        specialty: "Estética y belleza",
        status: "active"
      )
    end

    def create_service(business)
      category = ServiceCategory.find_or_create_for!(business: business, name: "Uñas", primary_category: true)
      business.services.create!(
        name: "Esmaltado",
        service_category: category,
        category: category.name,
        description: "Servicio de uñas.",
        duration_minutes: 30,
        price_cents: 2_000_000,
        active: true,
        visibility_mode: "public",
        public_visible: true
      )
    end
end
