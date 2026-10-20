require "rails_helper"

RSpec.describe "Legacy customer deposit proof endpoints", type: :request do
  before { host! "localhost" }

  it "keeps the former public review endpoints inactive" do
    appointment = create_manual_deposit_appointment

    get deposit_review_path(appointment.deposit_review_token), headers: browser_headers
    expect(response).to have_http_status(:not_found)

    expect do
      post confirm_deposit_review_path(appointment.deposit_review_token), headers: browser_headers
    end.not_to change { appointment.reload.status }
    expect(response).to have_http_status(:not_found)

    expect do
      post reject_deposit_review_path(appointment.deposit_review_token), params: { reason: "No coincide" }, headers: browser_headers
    end.not_to change { appointment.reload.deposit_status }
    expect(response).to have_http_status(:not_found)
  end

  it "keeps the former public upload endpoint inactive" do
    appointment = create_manual_deposit_appointment

    get deposit_receipt_path(appointment.deposit_upload_token), headers: browser_headers

    expect(response).to have_http_status(:not_found)
  end

  private

    def create_manual_deposit_appointment
      owner = User.create!(email_address: "legacy-deposit-#{SecureRandom.hex(4)}@example.com", role: :admin)
      business = Business.create!(owner: owner, name: "Patitas Legacy", slug: "patitas-legacy-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 5555-5555", onboarding_completed_at: Time.current)
      service = business.services.create!(name: "Baño", category: "Baño", duration_minutes: 45, price_cents: 20_000_00, deposit_required: true, deposit_amount_cents: 5_000_00)
      business.appointments.create!(
        service: service,
        customer_name: "Valentina Gómez",
        customer_phone: "+54 9 11 1111-1111",
        starts_at: 2.days.from_now,
        status: :pending_deposit_review,
        source: :public_booking,
        deposit_status: "submitted",
        payment_collection_method: "manual_proof",
        deposit_amount_cents: 5_000_00,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )
    end

    def browser_headers
      { "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36" }
    end
end
