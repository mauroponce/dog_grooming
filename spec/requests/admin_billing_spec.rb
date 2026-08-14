require "rails_helper"

RSpec.describe "Admin billing", type: :request do
  before { host! "localhost:3000" }

  it "renders the subscription page with subscription history" do
    user, business = create_admin_with_business
    subscription = business.subscription
    create_invoice(
      business: business,
      subscription: subscription,
      status: "open",
      due_on: Date.new(2026, 7, 31),
      reference_code: "HT-BILL-#{SecureRandom.hex(4).upcase}"
    )
    create_invoice(
      business: business,
      subscription: subscription,
      status: "paid",
      due_on: Date.new(2026, 6, 30),
      reference_code: "HT-PAID-#{SecureRandom.hex(4).upcase}"
    )

    sign_in(user)
    get admin_billing_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Tu suscripción")
    expect(response.body).to include("Suscripción Dog Grooming")
    expect(response.body).to include("Historial de pagos")
    expect(response.body).to include("Datos para transferir")
    expect(response.body).to include("Subir comprobante")
    expect(response.body).to include("1 pagos aprobados")
  end

  it "uploads a payment proof for the current invoice" do
    user, business = create_admin_with_business
    invoice = create_invoice(
      business: business,
      subscription: business.subscription,
      status: "open",
      due_on: Date.new(2026, 7, 31),
      reference_code: "HT-UPLOAD-#{SecureRandom.hex(4).upcase}"
    )
    delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)

    allow(BillingMailer).to receive(:payment_proof_received).and_return(delivery)

    sign_in(user)
    post upload_payment_proof_admin_billing_path,
      params: {
        payment_proof: Rack::Test::UploadedFile.new(
          Rails.root.join("spec/fixtures/files/service-gallery.png"),
          "image/png",
          original_filename: "comprobante.png"
        )
      },
      headers: browser_headers

    expect(response).to redirect_to(admin_billing_path(anchor: "historial"))
    expect(invoice.reload.status).to eq("pending_review")
    expect(invoice.subscription.reload.status).to eq("pending_review")
    expect(invoice.current_proof).to be_present
    expect(invoice.current_proof.file).to be_attached
    expect(invoice.current_proof.file.blob.key).to include("#{business.slug}/suscripcion/comprobantes/")
    expect(BillingMailer).to have_received(:payment_proof_received).with(invoice.current_proof)
    expect(delivery).to have_received(:deliver_later)
  end

  it "hides billing for free businesses" do
    user, business = create_admin_with_business
    business.update!(billing_enabled: false)

    sign_in(user)
    get admin_customer_profiles_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Ver suscripción")
    expect(response.body).not_to include(%(href="#{admin_billing_path}"))

    get admin_billing_path, headers: browser_headers

    expect(response).to redirect_to(admin_calendar_path)
  end

  private
    def create_admin_with_business
      user = User.create!(
        email_address: "admin-billing-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :admin
      )
      business = Business.create!(
        owner: user,
        name: "Estética Billing",
        slug: "estetica-billing-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 4444-4444",
        onboarding_completed_at: Time.current
      )

      [ user, business ]
    end

    def create_invoice(business:, subscription:, status:, due_on:, reference_code:)
      subscription.subscription_invoices.create!(
        business: business,
        period_start: due_on,
        period_end: due_on.advance(months: 1),
        billing_period_months: 1,
        amount_cents: business.billing_amount.total_amount_cents,
        due_on: due_on,
        reference_code: reference_code,
        status: status
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
