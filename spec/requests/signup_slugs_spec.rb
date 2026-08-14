require "rails_helper"

RSpec.describe "Signup slugs", type: :request do
  before { host! "localhost" }

  describe "GET /signup/slug_suggestions" do
    it "returns the registration closed response" do
      create_business(slug: "estetica-mauro")

      get signup_slug_suggestions_path, params: { name: "Estética Mauro" }, headers: browser_headers

      expect(response).to have_http_status(:gone)
      payload = JSON.parse(response.body)
      expect(payload).to include(
        "available" => false,
        "message" => "Por ahora creamos las cuentas desde Dog Grooming."
      )
    end
  end

  describe "GET /signup/slug_availability" do
    it "returns the registration closed response when the slug exists" do
      create_business(slug: "estetica-mauro")

      get signup_slug_availability_path, params: { slug: "estetica-mauro" }, headers: browser_headers

      expect(response).to have_http_status(:gone)
      payload = JSON.parse(response.body)
      expect(payload).to include(
        "available" => false,
        "message" => "Por ahora creamos las cuentas desde Dog Grooming."
      )
    end

    it "returns the registration closed response for a free valid slug" do
      get signup_slug_availability_path, params: { slug: "estetica-mauro-palermo" }, headers: browser_headers

      expect(response).to have_http_status(:gone)
      payload = JSON.parse(response.body)
      expect(payload).to include(
        "available" => false,
        "message" => "Por ahora creamos las cuentas desde Dog Grooming."
      )
    end
  end

  def create_business(slug:)
    owner = User.create!(
      email_address: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    Business.create!(
      owner: owner,
      name: "Estética Mauro",
      slug: slug,
      contact_phone: "+54 9 11 2222-2222",
      onboarding_completed_at: Time.current
    )
  end

  def browser_headers
    {
      "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36",
      "HTTP_USER_AGENT" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"
    }
  end
end
