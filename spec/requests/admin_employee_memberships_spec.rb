require "rails_helper"

RSpec.describe "Admin employee memberships", type: :request do
  it "renders the team index without configurable role controls" do
    owner = User.create!(email_address: "team-owner-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    business = Business.create!(owner:, name: "Equipo", slug: "equipo-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-5555", onboarding_completed_at: Time.current)
    business.employee_memberships.create!(name: "Ada Lovelace", email_address: "ada-#{SecureRandom.hex(4)}@example.com", status: "active")
    sign_in(owner)

    get admin_employee_memberships_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ada Lovelace")
    expect(response.body).not_to include("Gestionar permisos")
    expect(response.body).not_to include("Editar rol de")
  end

  it "sends an invitation and does not expose configurable permissions" do
    owner = User.create!(email_address: "owner-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    business = Business.create!(owner:, name: "Pichipurris", slug: "pichipurris-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-5555", onboarding_completed_at: Time.current)
    sign_in(owner)

    post admin_employee_memberships_path, params: { employee_membership: { first_name: "Mauro", last_name: "Ponce", email_address: "mauro@example.com", phone: "+54 9 11 4444-4444" } }, headers: browser_headers

    employee = business.employee_memberships.order(:created_at).last
    expect(response).to redirect_to(admin_employee_memberships_path)
    expect(employee).to be_pending
    expect(employee.invitation_token_digest).to be_present

    get new_admin_employee_membership_path, headers: browser_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Permisos")
  end

  it "renders the Google invitation form without Turbo" do
    owner = User.create!(email_address: "invitation-owner-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    business = Business.create!(owner:, name: "Invitaciones", slug: "invitaciones-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-5555", onboarding_completed_at: Time.current)
    membership = business.employee_memberships.create!(name: "Ada Lovelace", first_name: "Ada", last_name: "Lovelace", email_address: "ada-#{SecureRandom.hex(4)}@example.com")
    membership.invite!(invited_by: owner)

    get employee_invitation_path(membership.raw_invitation_token), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    google_form = document.at_css("form.button_to")
    expect(response).to have_http_status(:ok)
    expect(google_form["action"]).to eq("/auth/google_oauth2?origin=employee_invitation:#{membership.raw_invitation_token}")
    expect(google_form["method"]).to eq("post")
    expect(google_form["data-turbo"]).to eq("false")
  end

  private

    def sign_in(user)
      session = user.sessions.create!(user_agent: browser_headers.fetch("User-Agent"), ip_address: "127.0.0.1")
      allow_any_instance_of(ApplicationController).to receive(:resume_session) { Current.session = session }
      allow_any_instance_of(ApplicationController).to receive(:verified_request?).and_return(true)
    end

    def browser_headers
      { "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36" }
    end
end
