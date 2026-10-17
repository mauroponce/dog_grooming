require "rails_helper"
require "nokogiri"

RSpec.describe "Admin shell", type: :request do
  before { host! "localhost" }

  it "requires authentication" do
    get admin_root_path, headers: browser_headers

    expect(response).to redirect_to(new_session_path)
  end

  it "uses the calendar as the only admin landing page" do
    user, business = create_admin_with_business
    sign_in(user)

    get admin_root_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Calendario")
    expect(response.body).to include(%(href="#{admin_root_path}"))
    expect(response.body).not_to include(%(id="waitlistToolbarButton"))
    expect(response.body).not_to include("Asistente")
    expect(business).to be_present
  end

  it "marks all notifications as read and returns to the calendar" do
    user, business = create_admin_with_business
    business.provider_events.create!(event_type: "new_booking", title: "Nueva reserva", body: "Hay un turno nuevo")
    sign_in(user)

    patch mark_all_read_admin_notifications_path, headers: browser_headers.merge("HTTP_REFERER" => admin_root_url)

    expect(response).to redirect_to(admin_root_path)
    expect(business.provider_events.unread).to be_empty
  end

  it "updates only permitted schedule fields" do
    user, business = create_admin_with_business
    sign_in(user)

    patch admin_settings_path, params: {
      settings_tab: "horarios-de-atencion",
      availability_rules: {
        "1" => {
          active: "1",
          start_time: "08:30",
          end_time: "17:30",
          break_start_time: "12:00",
          break_end_time: "13:00",
          business_id: -1,
          unexpected: "ignored"
        }
      }
    }, headers: browser_headers

    expect(response).to redirect_to(admin_settings_path(settings_tab: "horarios-de-atencion", anchor: "horarios-de-atencion"))
    monday = business.availability_rules.find_by!(weekday: 1)
    expect(monday).to have_attributes(active: true)
    expect(monday.start_time.strftime("%H:%M")).to eq("08:30")
    expect(monday.end_time.strftime("%H:%M")).to eq("17:30")
    expect(monday.business_id).to eq(business.id)
  end

  it "creates and chooses a manual-transfer account while ignoring extra attributes" do
    user, business = create_admin_with_business
    sign_in(user)

    patch admin_settings_path, params: {
      settings_tab: "cuentas-de-cobro",
      payment_accounts: {
        primary_key: "new-account",
        items: {
          "new-account" => {
            name: "Cuenta principal",
            details: "Alias: PATITAS.DEMO",
            active: "0",
            business_id: -1
          }
        }
      }
    }, headers: browser_headers

    expect(response).to redirect_to(admin_settings_path(settings_tab: "cuentas-de-cobro", anchor: "cuentas-de-cobro"))
    account = business.payment_accounts.find_by!(name: "Cuenta principal")
    expect(account).to be_active
    expect(account).to be_primary_account
    expect(account.business_id).to eq(business.id)
  end

  it "stores the public website content selected in settings" do
    user, business = create_admin_with_business
    sign_in(user)

    patch admin_settings_path, params: {
      settings_tab: "diseno-web",
      business_account: {
        business_name: business.name,
        owner_name: user.name,
        owner_email: user.email_address,
        contact_phone: business.contact_phone,
        slug: business.slug,
        public_site_mode: "full_website",
        public_custom_html: '<section class="ht-about"><h2>Quiénes somos</h2></section>',
        public_category_custom_html: '<section><h1>{{category_name}}</h1><div data-dog-grooming-slot="services"></div></section>'
      }
    }, headers: browser_headers

    expect(response).to redirect_to(admin_settings_path(settings_tab: "diseno-web", anchor: "diseno-web"))
    expect(business.reload.public_site_mode).to eq("full_website")
    expect(business.public_custom_html).to include("Quiénes somos")
    expect(business.public_category_custom_html).to include("{{category_name}}")
  end

  it "creates a manual calendar appointment for an existing customer and pet" do
    user, business = create_admin_with_business
    membership = create_owner_membership(user, business)
    service = business.services.create!(name: "Baño", category: "Baño", duration_minutes: 60, price_cents: 20_000_00)
    customer = business.customer_profiles.create!(name: "Ada Lovelace", phone: "+54 9 11 3333-3333")
    pet = customer.pets.create!(business: business, name: "Nina")
    starts_at = 3.days.from_now.change(hour: 10, min: 0)
    sign_in(user)

    expect do
      post admin_appointments_path(format: :json), params: {
        appointment: {
          service_id: service.id,
          customer_profile_id: customer.id,
          pet_id: pet.id,
          employee_membership_id: membership.id,
          customer_name: customer.name,
          customer_phone: customer.phone,
          starts_at: starts_at.iso8601
        }
      }, headers: browser_headers.merge("Accept" => "application/json")
    end.to change { business.appointments.count }.by(1)

    expect(response).to have_http_status(:created)
    appointment = business.appointments.order(:created_at).last
    expect(appointment).to have_attributes(source: "manual", customer_profile_id: customer.id, pet_id: pet.id)
  end

  it "requires a reason when the center cancels a booking" do
    user, business = create_admin_with_business
    service = business.services.create!(name: "Baño", category: "Baño", duration_minutes: 60, price_cents: 20_000_00)
    appointment = business.appointments.create!(
      service: service,
      customer_name: "Ada Lovelace",
      customer_phone: "+54 9 11 3333-3333",
      starts_at: 3.days.from_now.change(hour: 10),
      status: :confirmed,
      source: :public_booking,
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )
    sign_in(user)

    patch cancel_admin_appointment_path(appointment, format: :json), params: { reason: " " }, headers: browser_headers.merge("Accept" => "application/json")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch("errors")).to include("Indicá el motivo de la cancelación.")
    expect(appointment.reload).to be_confirmed
  end

  def create_admin_with_business
    user = User.create!(
      email_address: "admin-shell-#{SecureRandom.hex(4)}@example.test",
      name: "Juliana Admin",
      role: :admin
    )
    business = Business.create!(
      owner: user,
      name: "Patitas Test",
      slug: "patitas-test-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 4444-4444",
      onboarding_completed_at: Time.current
    )
    [ user, business ]
  end

  def create_owner_membership(user, business)
    business.employee_memberships.create!(
      user: user,
      invited_by: user,
      name: user.name,
      first_name: "Juliana",
      last_name: "Admin",
      email_address: user.email_address,
      status: "active",
      invitation_accepted_at: Time.current,
      permissions: EmployeeMembership::PERMISSIONS.keys.index_with { true }
    )
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
end
