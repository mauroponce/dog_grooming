require "rails_helper"
require "nokogiri"

RSpec.describe "Admin tutorials", type: :request do
  before { host! "localhost" }

  it "shows Super Admin tutorials in the left navigation and embeds the selected video" do
    admin, = create_admin_with_business
    first_tutorial = Tutorial.create!(title: "Configurar tu página de reservas", video_url: "https://www.loom.com/share/c260f183787c4d5ab493571d4fd1bab3")
    second_tutorial = Tutorial.create!(title: "Gestionar señas", video_url: "https://vimeo.com/987654")

    sign_in(admin)
    get admin_tutorials_path(tutorial_id: first_tutorial.id), headers: browser_headers

    document = Nokogiri::HTML(response.body)
    navigation = document.at_css(".tutorials-navigation")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Tutoriales")
    expect(response.body).not_to include("Aprendé a usar Dog Grooming")
    expect(response.body).not_to include("Encontrá guías en video para configurar y aprovechar las herramientas de tu negocio.")
    expect(response.body).to include(first_tutorial.title)
    expect(response.body).to include(second_tutorial.title)
    expect(navigation).to be_present
    expect(document.at_css(".tutorials-layout").element_children.first.name).to eq("aside")
    expect(navigation.at_css("a[href='#{admin_tutorials_path(tutorial_id: first_tutorial.id)}']")["class"]).to include("is-active")
    expect(document.at_css(".tutorials-video-frame")["src"]).to eq("https://www.loom.com/embed/c260f183787c4d5ab493571d4fd1bab3")
    expect(document.at_css(".tutorials-video-frame")["title"]).to eq(first_tutorial.title)
    expect(document.at_css(".tutorials-content-body")).to be_nil
    expect(document.at_css(".tutorials-video-link")).to be_nil
  end

  it "renders an empty state when no tutorial has been published" do
    admin, = create_admin_with_business

    sign_in(admin)
    get admin_tutorials_path, headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Próximamente habrá tutoriales acá")
    expect(response.body).to include("Todavía no hay tutoriales publicados.")
  end

  private
    def create_admin_with_business
      admin = create_user(role: :admin, email_prefix: "tutorials-owner")
      business = Business.create!(
        owner: admin,
        name: "Tutoriales Center",
        slug: "tutoriales-center-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-1234",
        onboarding_completed_at: Time.current
      )
      [ admin, business ]
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

    def create_user(role:, email_prefix:)
      User.create!(
        email_address: "#{email_prefix}-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: role
      )
    end
end
