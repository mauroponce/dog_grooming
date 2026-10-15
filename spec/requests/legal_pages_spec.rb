require "rails_helper"

RSpec.describe "Legal pages", type: :request do
  before { host! "localhost" }

  it "renders the privacy policy publicly with its legal links" do
    get privacy_policy_path

    expect(response).to have_http_status(:ok)
    expect(response).not_to redirect_to(new_session_path)
    expect(response.body).to include("Política de Privacidad de Cita.pet")
    expect(response.body).to include("15 de octubre de 2026")
    expect(response.body).to include("Bynnon 1839, Adrogué, Buenos Aires, Argentina")
    expect(response.body).to include("persona humana adherida al régimen de monotributo")
    expect(response.body).to include("mgp1989@gmail.com")
    expect(response.body).to include(data_deletion_path)
    expect(response.body).not_to include("noindex")
  end

  it "renders the data deletion page publicly with the expected procedure" do
    get data_deletion_path

    expect(response).to have_http_status(:ok)
    expect(response).not_to redirect_to(new_session_path)
    expect(response.body).to include("Eliminación de datos personales — Cita.pet")
    expect(response.body).to include("Solicitud de eliminación de datos — Cita.pet")
    expect(response.body).to include("mgp1989@gmail.com")
    expect(response.body).to include(privacy_policy_path)
  end

  it "links both legal pages from the public landing footer" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(privacy_policy_path)
    expect(response.body).to include(data_deletion_path)
  end
end
