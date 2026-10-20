require "rails_helper"

RSpec.describe "Admin billing", type: :request do
  before { host! "localhost:3000" }

  it "muestra el pago por transferencia para una factura pendiente" do
    business = create_business
    BillingTransferAccount.current.update!(transfer_alias: "cita.pet", account_holder: "Cita.pet")
    sign_in(business.owner)

    get admin_billing_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Transferencia bancaria")
    expect(response.body).to include("cita.pet")
    expect(response.body).not_to include("Pagar con Mercado Pago")
  end

  it "muestra el estado, los días restantes y el vencimiento durante el trial" do
    owner = User.create!(email_address: "trial-owner-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    business = Business.create!(owner: owner, name: "Patitas Trial", slug: "patitas-trial-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 4444 4444", onboarding_completed_at: Time.current)
    sign_in(owner)

    get admin_billing_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("En prueba")
    expect(response.body).to include("Te quedan 14 días")
    expect(response.body).to include(I18n.l(business.subscription.trial_ends_on, format: :long))
  end

  it "mantiene accesible la suscripción y explica cómo recuperar una cuenta suspendida" do
    business = create_business
    business.subscription.update!(status: "suspended", suspended_at: Time.current, grace_ends_on: 1.day.ago.to_date)
    sign_in(business.owner)

    get admin_billing_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Tu cuenta está suspendida")
    expect(response.body).to include("Regularizá el pago")
  end

  def create_business
    owner = User.create!(email_address: "owner-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    Business.create!(owner: owner, name: "Patitas", slug: "patitas-#{SecureRandom.hex(4)}", contact_phone: "+54 9 11 4444 4444", onboarding_completed_at: Time.current, trial_ends_at: 1.day.ago)
  end

  def sign_in(user)
    session = user.sessions.create!(user_agent: browser_headers.fetch("User-Agent"), ip_address: "127.0.0.1")
    allow_any_instance_of(ApplicationController).to receive(:resume_session) { Current.session = session }
    allow_any_instance_of(ApplicationController).to receive(:verified_request?).and_return(true)
  end

  def browser_headers
    { "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36" }
  end
end
