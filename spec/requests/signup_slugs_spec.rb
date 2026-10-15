require "rails_helper"

RSpec.describe "Registro", type: :request do
  before { host! "localhost" }

  it "crea una peluquería con prueba de catorce días y envía al onboarding" do
    post registro_path, params: { registration: {
      business_name: "Patitas Felices", owner_name: "Mauro Ponce", contact_phone: "+54 9 11 5555 5555",
      email_address: "mauro-#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123", slug: "patitas-#{SecureRandom.hex(4)}"
    } }, headers: browser_headers

    business = Business.order(:created_at).last
    expect(response).to redirect_to(onboarding_schedule_path)
    expect(business.industry).to eq("dog_grooming")
    expect(business.trial_ends_at.to_date).to eq((business.trial_started_at + 14.days).to_date)
    expect(business.subscription.amount_cents).to eq(3_500_000)
    expect(business.onboarding_complete?).to be(false)
    expect(business.services.count).to eq(9)
    expect(business.simultaneous_capacity).to eq(3)
    expect(business.employee_memberships.available_for_booking).to be_empty
  end

  it "guarda la elección PRO y su precio mensual" do
    post registro_path, params: { registration: {
      business_name: "Patitas PRO", owner_name: "Mauro Ponce", contact_phone: "+54 9 11 5555 5555",
      email_address: "pro-#{SecureRandom.hex(4)}@example.com", password: "password123", password_confirmation: "password123", plan_selected: "pro"
    } }, headers: browser_headers
    expect(response).to redirect_to(onboarding_schedule_path)
    expect(Business.order(:created_at).last.subscription).to have_attributes(plan_selected: "pro", amount_cents: 4_500_000)
  end

  it "expone disponibilidad de slug" do
    get signup_slug_availability_path, params: { slug: "patitas-nuevo" }, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include("available" => true, "slug" => "patitas-nuevo")
  end

  def browser_headers
    { "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36" }
  end
end
