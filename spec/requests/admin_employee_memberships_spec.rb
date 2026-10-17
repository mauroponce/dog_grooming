require "rails_helper"

RSpec.describe "Admin employee memberships", type: :request do
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
