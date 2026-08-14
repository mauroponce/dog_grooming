require "rails_helper"

RSpec.describe "Admin profiles", type: :request do
  before { host! "localhost" }

  it "syncs the owner membership name when the user edits their profile" do
    user, business = create_admin_with_business
    business.employee_memberships.find_by!(user: user)

    sign_in(user)

    patch admin_profile_path, params: {
      user: {
        name: "Mauro Ponce",
        phone: "+54 9 11 1234-5678"
      }
    }, headers: browser_headers

    owner_membership = business.employee_memberships.find_by!(user: user)

    expect(response).to redirect_to(edit_admin_profile_path)
    expect(user.reload.name).to eq("Mauro Ponce")

    get admin_calendar_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Mauro Ponce")
  end

  it "syncs the user profile photo to the linked team member" do
    user, business = create_admin_with_business
    owner_membership = business.employee_memberships.find_by!(user: user)

    sign_in(user)

    patch admin_profile_path, params: {
      user: {
        name: "Mauro Ponce",
        phone: "+54 9 11 1234-5678",
        profile_photo: profile_photo_upload
      }
    }, headers: browser_headers

    expect(response).to redirect_to(edit_admin_profile_path)
    expect(user.reload.profile_photo).to be_attached
    expect(owner_membership.reload.profile_photo).to be_attached
    expect(owner_membership.profile_photo.blob.id).to eq(user.profile_photo.blob.id)
  end

  it "renders client-side password confirmation validation hooks" do
    user, = create_admin_with_business

    sign_in(user)
    get edit_admin_profile_path, headers: browser_headers

    document = Nokogiri::HTML(response.body)
    form = document.at_css("form[data-controller='password-confirmation']")

    expect(response).to have_http_status(:ok)
    expect(form).to be_present
    expect(form["data-action"]).to include("submit->password-confirmation#submit")
    expect(document.at_css("input[name='user[password]']")["data-password-confirmation-target"]).to eq("password")
    expect(document.at_css("input[name='user[password_confirmation]']")["data-password-confirmation-target"]).to eq("confirmation")
  end

  it "shows translated password confirmation errors from the server" do
    user, = create_admin_with_business

    sign_in(user)
    patch admin_profile_path, params: {
      user: {
        name: user.name,
        password: "password123",
        password_confirmation: "otra-password"
      }
    }, headers: browser_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Confirmación de contraseña no coincide con la contraseña")
    expect(response.body).not_to include("Translation missing")
    expect(response.body).not_to include("activerecord.errors")
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
      email_address: "admin-profile-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin,
      name: "Casa de Mangos"
    )
    business = Business.create!(
      owner: user,
      name: "Casa de Mangos",
      slug: "casa-de-mangos-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 9999-9999",
      onboarding_completed_at: Time.current
    )

    business.employee_memberships.create!(
      user: user,
      name: user.name,
      first_name: "Casa",
      last_name: "Mangos",
      email_address: user.email_address,
      phone: business.contact_phone,
      specialty: business.industry_label,
      branch: business.branches.first,
      status: "active",
      permissions: EmployeeMembership::PERMISSIONS.keys.index_with { true }
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
