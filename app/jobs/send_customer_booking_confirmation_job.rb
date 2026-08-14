class SendCustomerBookingConfirmationJob < ApplicationJob
  queue_as :default

  def perform(appointment)
    return unless appointment.confirmed?

    queue_email_once!(
      appointment,
      recipient: appointment.customer_email,
      template: "customer_booking_confirmed"
    ) { AppointmentMailer.customer_booking_confirmed(appointment) }

    if appointment.mercado_pago_payment_required?
      queue_email_once!(
        appointment,
        recipient: appointment.business.owner.email_address,
        template: "mercado_pago_booking_confirmed"
      ) { BusinessMailer.booking_confirmed_by_mercado_pago(appointment) }
    end

    send_whatsapp_confirmation!(appointment) if WhatsApp::AutomatedNotifications.enabled?
  end

  private
    def queue_email_once!(appointment, recipient:, template:)
      return if recipient.blank?

      delivery = appointment.with_lock do
        already_queued = appointment.notification_deliveries.where(
          channel: "email",
          recipient: recipient,
          template: template,
          status: %w[queued sent]
        ).exists?
        next if already_queued

        appointment.notification_deliveries.create!(
          business: appointment.business,
          channel: "email",
          recipient: recipient,
          template: template,
          status: "queued"
        )
      end
      yield.deliver_later if delivery
    end

    def send_whatsapp_confirmation!(appointment)
      return unless appointment.customer_phone.present?
      client = WhatsApp::EvolutionClient.new
      return unless client.configured?

      message = WhatsApp::MessageBuilder.new(
        business: appointment.business,
        template_key: "booking_confirmation",
        booking: appointment,
        customer: appointment.customer_profile,
        service: appointment.service,
        professional: appointment.employee_membership
      ).message
      return if message.blank?

      delivery = reserve_whatsapp_delivery!(appointment)
      return unless delivery

      response = client.send_text(
        number: appointment.customer_phone,
        text: message
      )

      delivery.update!(
        status: response[:success] ? "sent" : "failed",
        sent_at: Time.current,
        payload: response.slice(:status, :sanitized_body, :error)
      )
    rescue StandardError => error
      delivery&.update!(status: "failed", error_message: error.message) if delivery&.persisted?
      Rails.logger.warn("Customer booking WhatsApp confirmation failed for appointment #{appointment.id}: #{error.class} #{error.message}")
    end

    def reserve_whatsapp_delivery!(appointment)
      appointment.with_lock do
        already_delivered = appointment.notification_deliveries.where(
          channel: "whatsapp",
          recipient: appointment.customer_phone,
          template: "booking_confirmation",
          status: %w[queued sent]
        ).exists?
        next if already_delivered

        appointment.notification_deliveries.create!(
          business: appointment.business,
          channel: "whatsapp",
          recipient: appointment.customer_phone,
          template: "booking_confirmation",
          status: "queued"
        )
      end
    end
end
