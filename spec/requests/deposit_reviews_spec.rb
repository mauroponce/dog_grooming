require "rails_helper"
require "nokogiri"

RSpec.describe "Deposit reviews", type: :request do
  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  before do
    host! "localhost"
    allow_any_instance_of(ApplicationController).to receive(:verified_request?).and_return(true)
  end

  it "renders the mobile review page from the short deposit token" do
    appointment = create_deposit_review_appointment

    get deposit_review_path(appointment.deposit_review_token), headers: browser_headers

    document = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    expect(appointment.deposit_review_url).to include("/d/#{appointment.deposit_review_token}")
    expect(URI.parse(appointment.deposit_review_url).path.split("/")).not_to include(appointment.id.to_s)
    expect(response.body).to include("Comprobante de seña")
    expect(response.body).to include("Confirmar turno y abrir WhatsApp")
    expect(document.at_css("img[alt='Comprobante de Valentina Gómez']")).to be_present
  end

  it "keeps the receipt pending for the center's manual review" do
    appointment = create_deposit_review_appointment

    get deposit_review_path(appointment.deposit_review_token), headers: browser_headers

    appointment.reload

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Revisá la imagen antes de confirmar")
    expect(response.body).not_to include("Revisión inteligente")
    expect(response.body).not_to include("La IA ayuda a detectar datos del comprobante")
    expect(appointment).to be_pending_deposit_review
    expect(appointment.deposit_status).to eq("submitted")
  end

  it "approves the receipt and shows the prepared WhatsApp action" do
    appointment = create_deposit_review_appointment

    post confirm_deposit_review_path(appointment.deposit_review_token), headers: browser_headers

    appointment.reload

    expect(response).to have_http_status(:redirect)
    expect(response).to redirect_to(deposit_review_path(appointment.deposit_review_token))
    expect(appointment).to be_confirmed
    expect(appointment.deposit_status).to eq("approved")

    follow_redirect!

    document = Nokogiri::HTML(response.body)
    whatsapp_link = document.css("a[href^='https://wa.me/5491111111111']").find { |link| link.text.include?("WhatsApp") }

    expect(whatsapp_link).to be_present
    whatsapp_message = Rack::Utils.parse_query(URI.parse(whatsapp_link["href"]).query).fetch("text")
    expect(whatsapp_message).to include("Confirmamos tu seña")
    expect(whatsapp_message).to include("Depilación")
  end

  it "rejects the receipt and shows the prepared WhatsApp action" do
    appointment = create_deposit_review_appointment

    post reject_deposit_review_path(appointment.deposit_review_token),
      params: { reason: "El monto no coincide." },
      headers: browser_headers

    appointment.reload

    expect(response).to have_http_status(:redirect)
    expect(response).to redirect_to(deposit_review_path(appointment.deposit_review_token))
    expect(appointment).to be_pending_deposit
    expect(appointment.deposit_status).to eq("rejected")
    expect(appointment.deposit_rejection_reason).to eq("El monto no coincide.")

    follow_redirect!

    document = Nokogiri::HTML(response.body)
    whatsapp_link = document.css("a[href^='https://wa.me/5491111111111']").find { |link| link.text.include?("WhatsApp") }

    expect(whatsapp_link).to be_present
    whatsapp_message = Rack::Utils.parse_query(URI.parse(whatsapp_link["href"]).query).fetch("text")
    expect(whatsapp_message).to include("necesitamos que lo vuelvas a cargar")
    expect(whatsapp_message).to include("El monto no coincide.")
  end

  it "keeps legacy signed review links working" do
    appointment = create_deposit_review_appointment
    legacy_token = appointment.signed_id(expires_in: 7.days, purpose: :deposit_review)

    get legacy_deposit_review_path(legacy_token), headers: browser_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Comprobante de seña")
  end

  it "creates owner deposit events with the mobile review URL" do
    appointment = create_deposit_review_appointment
    appointment.update!(
      deposit_status: "pending",
      status: :pending_deposit,
      payment_collection_method: "manual_proof",
      payment_charge_mode: "deposit"
    )
    appointment.deposit_receipt.purge

    DepositProofs::ReplaceService.new(booking: appointment, file: image_upload).call

    event = appointment.business.provider_events.order(:created_at).last

    expect(event.event_type).to eq("deposit_receipt_submitted")
    expect(event.body).to include("subió comprobante de $3.500")
    expect(event.metadata.fetch("action_url")).to eq(appointment.deposit_review_url)
    expect(Admin::NotificationItem.new(event).action_url).to eq(appointment.deposit_review_url)
    expect(Admin::NotificationItem.new(event).notification_type).to eq("new_deposit_proof")
  end

  def create_deposit_review_appointment
    business = create_business
    service = create_service(business)
    starts_at = 2.days.from_now.change(hour: 16, min: 0, sec: 0)

    business.appointments.create!(
      service: service,
      customer_name: "Valentina Gómez",
      customer_phone: "+54 9 11 1111-1111",
      starts_at: starts_at,
      status: :pending_deposit_review,
      source: :public_booking,
      deposit_status: "submitted",
      deposit_amount_cents: 3_500_00,
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    ).tap do |appointment|
      appointment.deposit_receipt.attach(image_upload)
    end
  end

  def create_business
    owner = User.create!(
      email_address: "deposit-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )

    Business.create!(
      owner: owner,
      name: "Estética Burzaco",
      slug: "estetica-burzaco-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )
  end

  def create_service(business)
    business.services.create!(
      name: "Depilación",
      slug: "depilacion",
      category: "Estética",
      description: "Servicio de prueba.",
      duration_minutes: 30,
      price_cents: 12_000_00,
      active: true,
      public_visible: true,
      visibility_mode: "public",
      deposit_required: true,
      deposit_amount_cents: 3_500_00
    )
  end

  def image_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/service-gallery.png").to_s,
      "image/png"
    )
  end

  def browser_headers
    {
      "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36",
      "HTTP_USER_AGENT" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"
    }
  end
end
