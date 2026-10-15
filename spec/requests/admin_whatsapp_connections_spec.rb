require "rails_helper"
require "nokogiri"

RSpec.describe "Admin WhatsApp connections", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    keys = %w[META_CONFIG_ID META_APP_ID META_APP_SECRET META_EMBEDDED_SIGNUP_V4_CONFIRMED]
    previous = ENV.to_h.slice(*keys)
    ENV.update("META_CONFIG_ID" => "test-config", "META_APP_ID" => "test-app", "META_APP_SECRET" => "test-app-secret", "META_EMBEDDED_SIGNUP_V4_CONFIRMED" => "true")
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    keys.each { |key| previous.key?(key) ? ENV[key] = previous[key] : ENV.delete(key) }
    ActiveJob::Base.queue_adapter = adapter
  end

  before { host! "localhost" }
  let(:headers) { { "User-Agent" => "Mozilla/5.0 Chrome/130.0.0.0 Safari/537.36" } }
  let(:owner) { User.create!(email_address: "wa-owner-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin) }
  let(:business) { owner.create_business!(name: "Salon", slug: "wa-owner-#{SecureRandom.hex(4)}", onboarding_completed_at: Time.current) }

  def sign_in(user = owner)
    active_session = user.sessions.create!
    allow_any_instance_of(ApplicationController).to receive(:resume_session) { Current.session = active_session }
  end

  def signup_state
    business
    sign_in
    get admin_settings_path, headers: headers
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body).at_css('input[name="state"]')["value"]
  end

  def submit(state, **extra)
    post admin_whatsapp_connection_path, params: { state: state, code: "one-use-code", signup_event: WhatsApp::ConnectBusiness::FINISH_EVENT }.merge(extra), headers: headers
  end

  it "renders the connect button with public configuration, but no secret or token" do
    signup_state
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('[data-whatsapp-signup-config-id-value]')["data-whatsapp-signup-config-id-value"]).to eq("test-config")
    expect(response.body).to include("Conectar WhatsApp Business", "Coexistence")
    expect(response.body).not_to include("test-app-secret", "sessionInfoVersion", "Plantillas PRO")
  end

  it "blocks launch until the configuration is explicitly confirmed as v4" do
    ENV["META_EMBEDDED_SIGNUP_V4_CONFIRMED"] = "false"
    business
    sign_in
    get admin_settings_path, headers: headers
    expect(response.body).to include("No se iniciará un flujo antiguo")
    expect(Nokogiri::HTML(response.body).at_css('[data-controller="whatsapp-signup"]')).to be_nil
  end

  it "requires authentication" do
    expect(WhatsApp::ConnectBusiness).not_to receive(:call)
    submit("anything")
    expect(response).to redirect_to(new_session_path)
  end

  it "rejects employees even when they submit another tenant ID" do
    business
    employee = User.create!(email_address: "wa-employee-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :employee)
    business.employee_memberships.create!(user: employee, first_name: "Test", last_name: "Employee", email_address: employee.email_address, status: "active")
    sign_in(employee)
    expect(WhatsApp::ConnectBusiness).not_to receive(:call)
    submit("anything", business_id: business.id)
    expect(response).to have_http_status(:redirect)
  end

  it "binds the connection to the authenticated tenant, accepts missing asset IDs and never creates templates" do
    state = signup_state
    expect(WhatsApp::Templates).not_to receive(:ensure!)
    expect(WhatsApp::ConnectBusiness).to receive(:call).with(business: business, code: "one-use-code", event: WhatsApp::ConnectBusiness::FINISH_EVENT, waba_id: nil, phone_number_id: nil)
    submit(state, business_id: 99999)
    expect(response).to redirect_to(admin_settings_path)
    expect(flash[:notice]).to include("automatización sigue desactivada")
  end

  it "rejects invalid, expired and replayed signup state" do
    state = signup_state
    expect(WhatsApp::ConnectBusiness).not_to receive(:call)
    submit("wrong")
    submit(state)
    state = signup_state
    travel 16.minutes do
      submit(state)
      expect(flash[:alert]).to be_present
    end
  end

  it "cannot reuse a state after the authenticated account changes" do
    state = signup_state
    other = User.create!(email_address: "wa-other-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    other.create_business!(name: "Other", slug: "wa-other-#{SecureRandom.hex(4)}", onboarding_completed_at: Time.current)
    sign_in(other)
    expect(WhatsApp::ConnectBusiness).not_to receive(:call)
    submit(state)
    expect(flash[:alert]).to be_present
  end

  it "reports sanitized Meta permission codes, never exception contents" do
    state = signup_state
    allow(WhatsApp::ConnectBusiness).to receive(:call).and_raise(WhatsApp::CloudClient::Error.new("private-provider-details", code: 200, subcode: 201))
    submit(state)
    expect(flash[:alert]).to include("200/201")
    expect(flash[:alert]).not_to include("private-provider-details")
  end

  it "disconnects only the current tenant without deregistering any number" do
    business
    connection = business.create_whatsapp_connection!(phone_number_id: "123", waba_id: "456", access_token: "local-token", automation_enabled: true)
    other = User.create!(email_address: "wa-unrelated-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin).create_business!(name: "Other", slug: "wa-unrelated-#{SecureRandom.hex(4)}")
    other_connection = other.create_whatsapp_connection!(phone_number_id: "789", waba_id: "987", access_token: "other-token")
    sign_in
    expect(WhatsApp::CloudClient).not_to receive(:new)
    delete admin_whatsapp_connection_path, params: { business_id: other.id }, headers: headers
    expect(connection.reload.access_token).to be_nil
    expect(connection.automation_enabled).to be(false)
    expect(other_connection.reload.access_token).to eq("other-token")
  end
end
