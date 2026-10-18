require "rails_helper"

RSpec.describe "Public landing", type: :request do
  before { host! "localhost" }

  it "renders the current public booking and deposit flow" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("data-landing-page")
    expect(response.body).to include("Más mimos.")
    expect(response.body).to include("Señas por transferencia")
    expect(response.body).to include("14 días gratis")
    expect(response.body).to include(registro_path)
    expect(response.body).to include(new_session_path)
    expect(response.body).to include(privacy_policy_path)
    expect(response.body).to include(data_deletion_path)
    expect(response.body).not_to include("Mercado Pago")
    expect(response.body).not_to include("Asistente IA")
  end
end
