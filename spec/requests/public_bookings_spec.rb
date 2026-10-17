require "rails_helper"

RSpec.describe "Public bookings", type: :request do
  it "offers a new reservation and no customer self-service portal" do
    owner = User.create!(email_address: "booking-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    business = Business.create!(owner:, name: "Casa Tony", slug: "casa-tony-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-5555", onboarding_completed_at: Time.current, simultaneous_capacity: 1)
    business.services.create!(name: "Baño", slug: "bano", category: "Baño", duration_minutes: 60, price_cents: 15_000_00, active: true, public_visible: true, visibility_mode: "public")

    get new_public_booking_path(business.slug), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Contactar por WhatsApp")

    get "/#{business.slug}/mis-turnos", headers: browser_headers
    expect(response).to have_http_status(:found)
  end

  private

    def browser_headers
      { "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36" }
    end
end
