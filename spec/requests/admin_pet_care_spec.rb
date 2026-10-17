require "rails_helper"

RSpec.describe "Pet care", type: :request do
  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  before do
    host! "localhost"
    ActiveJob::Base.queue_adapter = :test
    @owner = User.create!(email_address: "care-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    @business = Business.create!(owner: @owner, name: "Peluquería", slug: "care-#{SecureRandom.hex(4)}", contact_phone: "1160347665", onboarding_completed_at: Time.current)
    @service = @business.services.create!(name: "Baño", slug: "bano", duration_minutes: 30, price_cents: 10000)
    @customer = @business.customer_profiles.create!(name: "Ana", phone: "1160347665", email: "ana@example.com")
    @pet = @customer.pets.create!(name: "Coco", notes: "Piel sensible", behavioral_alerts: [ "blower_fear" ], grooming_reference_note: "Cara redonda")
    @appointment = @business.appointments.create!(service: @service, customer_profile: @customer, pet: @pet, customer_name: "Ana", customer_phone: @customer.phone, starts_at: 2.hours.ago, status: :confirmed)
    sign_in(@owner)
  end

  it "opens the pet's care and history from the appointment" do
    get admin_appointment_details_path(@appointment, format: :json), headers: browser_headers
    expect(response.parsed_body["careUrl"]).to eq(care_admin_appointment_path(@appointment))
    get care_admin_appointment_path(@appointment), headers: browser_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Coco", "Piel sensible", "Se asusta con la turbina", "Cara redonda", "Finalizar", "Historial de Coco")
  end

  it "finishes with no note and accepts a note later without completing twice" do
    2.times { patch finalize_admin_appointment_path(@appointment), params: { finalization: { outcome: "completed" } }, headers: browser_headers }
    expect(@appointment.reload).to be_completed
    expect(@appointment.completed_by).to eq(@owner)
    expect(@appointment.booking_notes.count).to eq(0)
    expect(@business.provider_events.where(event_type: "appointment_completed").count).to eq(1)
    completed_at = @appointment.completed_at

    patch save_treatment_admin_appointment_path(@appointment), params: { finalization: { body: "Baño suave y corte de uñas" } }, headers: browser_headers
    expect(response).to redirect_to(care_admin_appointment_path(@appointment))
    expect(@appointment.booking_notes.sole.body).to eq("Baño suave y corte de uñas")
    expect(@appointment.reload.completed_at).to eq(completed_at)
    expect(@business.provider_events.where(event_type: "appointment_completed").count).to eq(1)
    get care_admin_appointment_path(@appointment), headers: browser_headers
    expect(response.body).to include("Baño suave y corte de uñas", "Completar atención")
  end

  it "suggests email matches and links only the selected appointment with an audit event" do
    other = @business.customer_profiles.create!(name: "Ana anterior", phone: "1177777777", email: "ana@example.com")
    pet = other.pets.create!(name: "Coco original")
    @appointment.update!(customer_email: "ana@example.com")
    get care_admin_appointment_path(@appointment), headers: browser_headers
    expect(response.body).to include("Hay coincidencias por email", "Ana anterior", "Coco original")
    expect(@appointment.reload.customer_profile).to eq(@customer)
    patch link_customer_admin_appointment_path(@appointment), params: { customer_profile_id: other.id, pet_id: pet.id }, headers: browser_headers
    expect(@appointment.reload.customer_profile).to eq(other)
    expect(@appointment.pet).to eq(pet)
    expect(@appointment.customer_phone).to eq("5491160347665")
    expect(@business.provider_events.where(event_type: "appointment_customer_linked").sole.user).to eq(@owner)
    expect(@customer.reload).to be_persisted
  end

  it "saves optional photos and enforces the per-appointment photo limit after completion" do
    photo = -> { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/service-gallery.png"), "image/png") }
    patch finalize_admin_appointment_path(@appointment), params: { finalization: { outcome: "completed", photos: [ photo.call ] } }, headers: browser_headers
    expect(@appointment.reload).to be_completed
    expect(@appointment.booking_attachments.post_appointment_photos.count).to eq(1)
    patch save_treatment_admin_appointment_path(@appointment), params: { finalization: { photos: [ photo.call, photo.call ] } }, headers: browser_headers
    expect(@appointment.booking_attachments.post_appointment_photos.count).to eq(3)
    patch save_treatment_admin_appointment_path(@appointment), params: { finalization: { photos: [ photo.call ], body: "Must roll back" } }, headers: browser_headers
    expect(@appointment.booking_attachments.post_appointment_photos.count).to eq(3)
    expect(@appointment.booking_notes.where(body: "Must roll back")).to be_empty
    expect(flash[:alert]).to include("hasta 3 fotos")
  end

  it "does not finish future or cancelled bookings" do
    @appointment.update!(starts_at: 2.days.from_now, ends_at: 2.days.from_now + 30.minutes)
    patch finalize_admin_appointment_path(@appointment), params: { finalization: { outcome: "completed" } }, headers: browser_headers
    expect(@appointment.reload).to be_confirmed
    @appointment.update!(status: :canceled)
    patch finalize_admin_appointment_path(@appointment), params: { finalization: { outcome: "completed" } }, headers: browser_headers
    expect(@appointment.reload).to be_canceled
  end

  it "rejects a pet from a different customer" do
    other = @business.customer_profiles.create!(name: "Otra", phone: "1177777777")
    patch link_customer_admin_appointment_path(@appointment), params: { customer_profile_id: other.id, pet_id: @pet.id }, headers: browser_headers
    expect(response).to have_http_status(:not_found)
    expect(@appointment.reload.pet).to eq(@pet)
  end

  it "prevents access to another business" do
    outsider = User.create!(email_address: "outside-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    Business.create!(owner: outsider, name: "Otra", slug: "other-#{SecureRandom.hex(4)}", contact_phone: "1177777777", onboarding_completed_at: Time.current)
    sign_in(outsider)
    get care_admin_appointment_path(@appointment), headers: browser_headers
    expect(response).to have_http_status(:not_found)
  end

  it "allows employees to finish only their assigned bookings and keeps customer editing separate" do
    employee = User.create!(email_address: "employee-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :employee)
    membership = @business.employee_memberships.create!(user: employee, name: "Sofi Perez", first_name: "Sofi", last_name: "Perez", email_address: employee.email_address, status: "active", permissions: { "can_edit_bookings" => true, "can_edit_internal_notes" => true, "can_complete_own_bookings" => true })
    @appointment.update!(employee_membership: membership)
    sign_in(employee)
    get care_admin_appointment_path(@appointment), headers: browser_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Actualizar ficha y cuidados", "Vincular a cliente existente")
    patch finalize_admin_appointment_path(@appointment), params: { finalization: { outcome: "completed" } }, headers: browser_headers
    expect(@appointment.reload).to be_completed
    patch link_customer_admin_appointment_path(@appointment), params: { customer_profile_id: @customer.id, pet_id: @pet.id }, headers: browser_headers
    expect(response).to have_http_status(:redirect)
    expect(@business.provider_events.where(event_type: "appointment_customer_linked")).to be_empty
    other_membership = @business.employee_memberships.find_or_initialize_by(user: @owner)
    other_membership.update!(name: "Otra persona", first_name: "Otra", last_name: "Persona", email_address: @owner.email_address, status: "active")
    @appointment.update!(employee_membership: other_membership)
    get care_admin_appointment_path(@appointment), headers: browser_headers
    expect(response).to have_http_status(:not_found)
  end

  def sign_in(user)
    session = user.sessions.create!(user_agent: browser_headers["User-Agent"], ip_address: "127.0.0.1")
    allow_any_instance_of(ApplicationController).to receive(:resume_session) { Current.session = session }
    allow_any_instance_of(ApplicationController).to receive(:verified_request?).and_return(true)
  end

  def browser_headers
    { "User-Agent" => "Mozilla/5.0 AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36" }
  end
end
