class SendOwnerEmailNotificationJob < ApplicationJob
  queue_as :default

  def perform(provider_event_id)
    event = ProviderEvent.find_by(id: provider_event_id)
    return if event.blank?

    appointment = appointment_for(event)
    return if appointment.blank?

    if customer_portal_cancellation?(event)
      queue_email_once!(
        appointment,
        recipient: event.business.owner.email_address,
        template: "business_booking_cancelled",
        provider_event_id: event.id
      ) { BusinessMailer.booking_cancelled(appointment) }
    end

    return unless customer_portal_cancellation?(event) || business_cancellation?(event, appointment)

    queue_email_once!(
      appointment,
      recipient: appointment.customer_email,
      template: "customer_booking_cancelled",
      provider_event_id: event.id
    ) { AppointmentMailer.customer_booking_cancelled(appointment) }
  end

  private
    def appointment_for(event)
      appointment_id = event.metadata["appointment_id"].presence
      event.business.appointments.find_by(id: appointment_id) if appointment_id.present?
    end

    def customer_portal_cancellation?(event)
      event.event_type == "customer_cancelled_booking"
    end

    def business_cancellation?(event, appointment)
      return false unless event.event_type == "booking_cancelled" && appointment.canceled?

      !Appointment::CUSTOMER_CANCELLATION_ACTORS.include?(event.metadata["canceled_by"].to_s)
    end

    def queue_email_once!(appointment, recipient:, template:, provider_event_id:)
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
          status: "queued",
          payload: { provider_event_id: provider_event_id }
        )
      end
      yield.deliver_later if delivery
    end
end
