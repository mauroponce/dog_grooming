require "rails_helper"
require "nokogiri"

RSpec.describe "Admin employee memberships", type: :request do
  before { host! "localhost" }

  it "creates a team member as active immediately" do
    user, business = create_admin_with_business
    service = business.services.create!(
      name: "Corte clásico",
      duration_minutes: 30,
      price_cents: 12_000_00
    )

    sign_in(user)

    expect {
      post admin_employee_memberships_path, params: {
        employee_membership: {
          first_name: "Mauro",
          last_name: "Ponce",
          email_address: "mauro@example.com",
          phone: "+54 9 11 4444-4444",
          specialty: "Peluquero",
          calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first,
          service_ids: [ service.id.to_s ]
        }
      }, headers: browser_headers
    }.to change(EmployeeMembership, :count).by(1)

    employee = business.employee_memberships.order(:created_at).last

    expect(response).to redirect_to(admin_employee_memberships_path)
    expect(employee).to have_attributes(
      status: "active",
      email_address: "mauro@example.com",
      specialty: "Peluquero",
      invited_by: user
    )
    expect(employee.can_receive_appointments).to be(true)
    expect(employee.invitation_sent_at).to be_nil
    expect(employee.invitation_expires_at).to be_nil
    expect(employee.invitation_token_digest).to be_nil
    expect(employee.invitation_accepted_at).to be_nil
    expect(employee.pending?).to be(false)
    expect(employee.active?).to be(true)
    expect(employee.service_ids).to eq([ service.id ])
  end

  it "renders the profession field on the team member form" do
    user, = create_admin_with_business

    sign_in(user)
    get new_admin_employee_membership_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    profession_input = document.at_css('input[name="employee_membership[specialty]"]')
    reservable_checkbox = document.at_css('input[name="employee_membership[can_receive_appointments]"][type="checkbox"]')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Profesión")
    expect(response.body).to include("Permite asignarle turnos a este profesional")
    expect(profession_input).to be_present
    expect(profession_input["placeholder"]).to eq("Ej: Peluquera")
    expect(reservable_checkbox).to be_present
    expect(reservable_checkbox["checked"]).to eq("checked")
  end

  it "renders the email field as editable on the team member edit form" do
    user, business = create_admin_with_business
    employee = business.employee_memberships.create!(
      first_name: "Lucia",
      last_name: "García",
      email_address: "lucia-editable@example.com",
      phone: "+54 9 11 5555-5555",
      status: "active",
      calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first
    )

    sign_in(user)
    get edit_admin_employee_membership_path(employee), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    email_input = document.at_css('input[name="employee_membership[email_address]"]')

    expect(response).to have_http_status(:ok)
    expect(email_input).to be_present
    expect(email_input["disabled"]).to be_nil
    expect(response.body).not_to include("El email de acceso no se modifica desde esta pantalla.")
  end

  it "renders the team member appointment history including canceled appointments" do
    user, business = create_admin_with_business
    employee = business.employee_memberships.create!(
      first_name: "Lucia",
      last_name: "García",
      email_address: "lucia-history@example.com",
      phone: "+54 9 11 5555-5555",
      status: "active",
      calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first
    )
    newer_service = business.services.create!(name: "Diseño de cejas", duration_minutes: 30, price_cents: 13_000_00)
    business.appointments.create!(
      employee_membership: employee,
      service: newer_service,
      customer_name: "Grace Hopper",
      customer_phone: "+54 9 11 6666-6666",
      starts_at: Time.zone.local(2026, 8, 5, 11),
      ends_at: Time.zone.local(2026, 8, 5, 11, 30),
      status: :confirmed
    )
    service = business.services.create!(name: "Laminado de cejas", duration_minutes: 45, price_cents: 22_000_00)
    appointment = business.appointments.create!(
      employee_membership: employee,
      service: service,
      customer_name: "Ada Lovelace",
      customer_phone: "+54 9 11 4444-4444",
      starts_at: Time.zone.local(2026, 8, 4, 11),
      ends_at: Time.zone.local(2026, 8, 4, 11, 45),
      status: :confirmed
    )
    appointment.cancel!(by: "customer_portal", reason: "El cliente no puede asistir.")

    sign_in(user)
    get edit_admin_employee_membership_path(employee), params: { section: "appointments" }, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    appointment_panel = document.at_css('[data-team-panel="appointments"]')
    appointment_row = document.at_css(".team-appointment--canceled")
    appointment_rows = document.css(".team-appointment")

    expect(response).to have_http_status(:ok)
    expect(appointment_panel["hidden"]).to be_nil
    expect(response.body).to include("Historial de turnos asignados")
    expect(appointment_rows.first.text.squish).to include("Diseño de cejas", "Grace Hopper", "05/08/2026")
    expect(appointment_row.text.squish).to include("Laminado de cejas", "Ada Lovelace", "04/08/2026", "Cancelado por Cliente", "El cliente no puede asistir.")
    expect(appointment_row.text).not_to include("August")
  end

  it "paginates the team member appointment history with a Turbo frame" do
    user, business = create_admin_with_business
    employee = business.employee_memberships.create!(
      first_name: "Lucia",
      last_name: "García",
      email_address: "lucia-pagination@example.com",
      phone: "+54 9 11 5555-5555",
      status: "active",
      calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first
    )
    service = business.services.create!(name: "Perfilado de cejas", duration_minutes: 30, price_cents: 13_000_00)

    21.times do |index|
      starts_at = Time.zone.local(2026, 8, 1, 10).advance(days: index)
      business.appointments.create!(
        employee_membership: employee,
        service: service,
        customer_name: "Cliente #{index}",
        customer_phone: "+54 9 11 6666-#{format('%04d', index)}",
        starts_at: starts_at,
        ends_at: starts_at + 30.minutes,
        status: :confirmed
      )
    end

    sign_in(user)
    get edit_admin_employee_membership_path(employee), params: { section: "appointments" }, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    next_link = document.at_css('turbo-frame#employee_appointment_history a[rel="next"]')
    rows = document.css("turbo-frame#employee_appointment_history .team-appointment")

    expect(rows.size).to eq(20)
    expect(rows.first.text.squish).to include("Cliente 20", "21/08/2026")
    expect(next_link["data-turbo-frame"]).to eq("employee_appointment_history")
    expect(next_link["href"]).to include("page=2")

    get edit_admin_employee_membership_path(employee), params: { section: "appointments", page: 2 }, headers: browser_headers

    page_two = Nokogiri::HTML(response.body)
    page_two_rows = page_two.css("turbo-frame#employee_appointment_history .team-appointment")
    expect(page_two_rows.size).to eq(1)
    expect(page_two_rows.first.text.squish).to include("Cliente 0", "01/08/2026")
  end

  it "updates a linked team member email and its access user email" do
    user, business = create_admin_with_business
    employee_user = User.create!(
      email_address: "linked-email-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :employee,
      name: "Lucia García"
    )
    employee = business.employee_memberships.create!(
      user: employee_user,
      first_name: "Lucia",
      last_name: "García",
      email_address: employee_user.email_address,
      phone: "+54 9 11 5555-5555",
      status: "active",
      calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first,
      can_receive_appointments: true
    )
    new_email = "nuevo-acceso-#{SecureRandom.hex(4)}@example.com"

    sign_in(user)

    patch admin_employee_membership_path(employee), params: {
      employee_membership: {
        first_name: "Lucia",
        last_name: "García",
        email_address: new_email.upcase,
        phone: "+54 9 11 5555-5555",
        specialty: "Peluquera",
        calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first,
        can_receive_appointments: "1",
        permission_keys: EmployeeMembership::DEFAULT_PERMISSIONS
      }
    }, headers: browser_headers

    expect(response).to redirect_to(admin_employee_memberships_path)
    expect(employee.reload.email_address).to eq(new_email)
    expect(employee_user.reload.email_address).to eq(new_email)
  end

  it "updates whether a team member can receive appointments" do
    user, business = create_admin_with_business
    employee = business.employee_memberships.create!(
      first_name: "Lucia",
      last_name: "García",
      email_address: "lucia-booking@example.com",
      phone: "+54 9 11 5555-5555",
      status: "active",
      calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first,
      can_receive_appointments: true
    )

    sign_in(user)

    patch admin_employee_membership_path(employee), params: {
      employee_membership: {
        first_name: "Lucia",
        last_name: "García",
        phone: "+54 9 11 5555-5555",
        specialty: "Recepción",
        calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first,
        can_receive_appointments: "0",
        permission_keys: EmployeeMembership::DEFAULT_PERMISSIONS
      }
    }, headers: browser_headers

    expect(response).to redirect_to(admin_employee_memberships_path)
    expect(employee.reload.can_receive_appointments).to be(false)
    expect(business.employee_memberships.available_for_booking).not_to include(employee)
  end

  it "syncs a linked team member profile photo to its user" do
    user, business = create_admin_with_business
    employee_user = User.create!(
      email_address: "linked-employee-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :employee,
      name: "Lucia García"
    )
    employee = business.employee_memberships.create!(
      user: employee_user,
      first_name: "Lucia",
      last_name: "García",
      email_address: employee_user.email_address,
      phone: "+54 9 11 5555-5555",
      status: "active",
      calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first,
      can_receive_appointments: true
    )

    sign_in(user)

    patch admin_employee_membership_path(employee), params: {
      employee_membership: {
        first_name: "Lucia",
        last_name: "García",
        phone: "+54 9 11 5555-5555",
        specialty: "Peluquera",
        calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first,
        can_receive_appointments: "1",
        profile_photo: profile_photo_upload,
        permission_keys: EmployeeMembership::DEFAULT_PERMISSIONS
      }
    }, headers: browser_headers

    expect(response).to redirect_to(admin_employee_memberships_path)
    expect(employee.reload.profile_photo).to be_attached
    expect(employee_user.reload.profile_photo).to be_attached
    expect(employee_user.profile_photo.blob.id).to eq(employee.profile_photo.blob.id)
  end

  it "permanently deletes a team member from the detail panel" do
    user, business = create_admin_with_business
    employee = business.employee_memberships.create!(
      first_name: "Lucia",
      last_name: "García",
      email_address: "lucia@example.com",
      phone: "+54 9 11 5555-5555",
      status: "active",
      calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first
    )

    sign_in(user)

    expect {
      delete permanently_destroy_admin_employee_membership_path(employee), headers: browser_headers
    }.to change(EmployeeMembership, :count).by(-1)

    expect(response).to redirect_to(admin_employee_memberships_path)
    expect(business.employee_memberships.find_by(id: employee.id)).to be_nil
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
      email_address: "admin-team-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )
    business = Business.create!(
      owner: user,
      name: "Centro Prueba",
      slug: "centro-prueba-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 2222-2222",
      onboarding_completed_at: Time.current
    )

    [ user, business ]
  end

  def profile_photo_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/service-gallery.png").to_s,
      "image/png"
    )
  end
end
