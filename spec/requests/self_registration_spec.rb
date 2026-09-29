require "rails_helper"

RSpec.describe "Registro de negocios", type: :request do
  before { host! "localhost:3003" }

  let(:headers) do
    { "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36" }
  end

  it "crea una cuenta con prueba de 14 días y contraseña elegida por el dueño" do
    post registro_path, params: { registration: {
      business_name: "Perritos Felices", owner_name: "Ana Pérez",
      owner_email: "ana@example.com", contact_phone: "+54 11 5555 5555",
      password: "clave-segura-123", password_confirmation: "clave-segura-123"
    } }, headers: headers

    expect(response).to redirect_to(admin_root_path)
    user = User.find_by!(email_address: "ana@example.com")
    expect(user.authenticate("clave-segura-123")).to eq(user)
    expect(user.authenticate(SuperAdmin::CreateBusinessAccount::DEFAULT_PASSWORD)).to be_falsey
    expect(user.business.trial_ends_at.to_i - user.business.trial_started_at.to_i).to eq(14.days.to_i)
    expect(user.business.subscription.provider).to eq("mercado_pago")

    user.business.update!(trial_ends_at: 1.minute.ago)
    expect(user.business.reload.access_active?).to be(false)
    get admin_root_path, headers: headers
    expect(response).to redirect_to(admin_billing_path)
  end

  it "no crea la cuenta si las contraseñas difieren" do
    expect {
      post registro_path, params: { registration: {
        business_name: "Perritos Felices", owner_name: "Ana Pérez",
        owner_email: "ana@example.com", contact_phone: "+54 11 5555 5555",
        password: "clave-segura-123", password_confirmation: "otra-clave-123"
      } }, headers: headers
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
