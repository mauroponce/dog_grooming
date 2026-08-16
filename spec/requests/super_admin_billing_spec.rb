require "rails_helper"

RSpec.describe "Super admin billing", type: :request do
  before { host! "localhost:3000" }

  it "lets a super admin configure transfer details and review a proof" do
    super_admin = create_user(role: :super_admin, email_prefix: "super-billing")
    business = create_business
    invoice = create_invoice(business)
    proof = invoice.subscription_payment_proofs.create!(
      business: business,
      uploaded_by: business.owner,
      uploaded_at: Time.current,
      status: "pending_review"
    )
    proof.file.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/service-gallery.png")),
      filename: "comprobante.png",
      content_type: "image/png"
    )

    sign_in(super_admin)
    get super_admin_billing_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cuenta para recibir pagos")
    expect(response.body).to include("Comprobantes para revisar")
    expect(response.body).to include(business.name)
    expect(response.body).to include("Abrir comprobante")

    patch super_admin_billing_path,
      params: {
        billing_transfer_account: {
          transfer_alias: "dog.grooming",
          cbu: "0000003100012345678901",
          account_holder: "Cita.pet SRL",
          tax_id: "30-12345678-9"
        }
      },
      headers: browser_headers

    account = BillingTransferAccount.current
    expect(response).to redirect_to(super_admin_billing_path)
    expect(account.transfer_alias).to eq("dog.grooming")
    expect(account.cbu).to eq("0000003100012345678901")

    allow(BillingMailer).to receive(:payment_approved).and_return(instance_double(ActionMailer::MessageDelivery, deliver_later: true))
    patch approve_payment_proof_super_admin_billing_path(proof_id: proof.id), headers: browser_headers

    expect(response).to redirect_to(super_admin_billing_path)
    expect(proof.reload).to be_approved
    expect(invoice.reload).to be_paid
  end

  it "does not allow non-super-admins to access internal billing" do
    user = create_user(role: :admin, email_prefix: "admin-billing")

    sign_in(user)
    get super_admin_billing_path, headers: browser_headers

    expect(response).to redirect_to(root_path)
  end

  private
    def create_user(role:, email_prefix:)
      User.create!(
        email_address: "#{email_prefix}-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: role
      )
    end

    def create_business
      owner = create_user(role: :admin, email_prefix: "owner-billing")
      Business.create!(
        owner: owner,
        name: "Estética Cobros",
        slug: "estetica-cobros-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 4444-4444",
        onboarding_completed_at: Time.current
      )
    end

    def create_invoice(business)
      due_on = Time.zone.today
      business.subscription.subscription_invoices.create!(
        business: business,
        period_start: due_on,
        period_end: due_on.advance(months: 1),
        billing_period_months: 1,
        amount_cents: business.monthly_amount_cents,
        due_on: due_on,
        reference_code: "HT-SUPER-#{SecureRandom.hex(4).upcase}",
        status: "pending_review"
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
