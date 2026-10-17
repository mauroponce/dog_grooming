require "rails_helper"

RSpec.describe DepositProofs::ReplaceService do
  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it "queues the admin review email and action without confirming the booking" do
    appointment = create_pending_deposit_appointment
    delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)

    expect(BusinessMailer).to receive(:new_deposit_proof).with(appointment).and_return(delivery)
    expect(SendCustomerBookingConfirmationJob).not_to receive(:perform_later)

    described_class.new(booking: appointment, file: image_upload).call

    appointment.reload
    event = appointment.business.provider_events.order(:created_at).last
    notification = appointment.notification_deliveries.find_by!(template: "deposit_receipt_submitted")

    expect(delivery).to have_received(:deliver_later).once
    expect(appointment).to be_pending_deposit_review
    expect(appointment.deposit_status).to eq("submitted")
    expect(appointment.deposit_receipt).to be_attached
    expect(notification).to have_attributes(
      channel: "email",
      recipient: appointment.business.owner.email_address,
      status: "queued"
    )
    expect(event.event_type).to eq("deposit_receipt_submitted")
    expect(event.title).to eq("Nuevo comprobante para revisar")
    expect(event.metadata.fetch("action_url")).to eq(appointment.deposit_review_url)
    expect(Admin::NotificationItem.new(event).notification_type).to eq("new_deposit_proof")
  end

  private
    def create_pending_deposit_appointment
      owner = User.create!(
        email_address: "deposit-owner-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :admin
      )
      business = Business.create!(
        owner: owner,
        name: "Aura Estética",
        slug: "aura-estetica-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-5555",
        onboarding_completed_at: Time.current
      )
      service = business.services.create!(
        name: "Depilación",
        slug: "depilacion-#{SecureRandom.hex(4)}",
        duration_minutes: 30,
        price_cents: 12_000_00,
        active: true,
        public_visible: true,
        visibility_mode: "public",
        deposit_required: true,
        deposit_amount_cents: 3_000_00
      )
      starts_at = 2.days.from_now.change(hour: 11, min: 0, sec: 0)

      business.appointments.create!(
        service: service,
        customer_name: "Valentina Gómez",
        customer_phone: "+54 9 11 2222-2222",
        starts_at: starts_at,
        ends_at: starts_at + service.duration_minutes.minutes,
        source: :public_booking,
        status: :pending_deposit,
        deposit_status: "pending",
        payment_collection_method: "manual_proof",
        payment_charge_mode: "deposit",
        deposit_amount_cents: 3_000_00,
        base_price_cents: service.price_cents,
        final_price_cents: service.price_cents
      )
    end

    def image_upload
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/service-gallery.png").to_s,
        "image/png"
      )
    end
end
