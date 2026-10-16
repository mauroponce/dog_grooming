class SendAppointmentReservedMessageJob < ApplicationJob
  queue_as :default

  def perform(appointment)
    queue_admin_access_email_once!(appointment)

    create_event!(appointment, "new_booking", "Nueva reserva para revisar", "#{appointment.customer_name} solicitó turno para #{appointment.service.name}.") unless appointment.deposit_submitted?
  end

  private
    def queue_admin_access_email_once!(appointment)
      recipient = appointment.business.owner.email_address.to_s.strip.downcase
      return if recipient.blank?

      delivery = appointment.with_lock do
        already_queued = appointment.notification_deliveries.where(
          channel: "email",
          recipient: recipient,
          template: "new_booking",
          status: %w[queued sent]
        ).exists?
        next if already_queued

        appointment.notification_deliveries.create!(
          business: appointment.business,
          channel: "email",
          recipient: recipient,
          template: "new_booking",
          status: "queued",
          sent_at: Time.current,
          payload: { admin_url: admin_appointment_url_for(appointment) }
        )
      end
      AppointmentMailer.new_booking(appointment).deliver_later if delivery
    end

    def create_event!(appointment, event_type, title, body)
      appointment.business.provider_events.create!(
        event_type: event_type,
        title: title,
        body: body,
        metadata: {
          appointment_id: appointment.id,
          action_url: admin_appointment_url_for(appointment)
        }.compact
      )
    end

    def admin_appointment_url_for(appointment)
      Rails.application.routes.url_helpers.admin_appointment_url(
        appointment,
        host: app_host,
        protocol: app_protocol
      )
    end

    def app_host
      AppUrl.host
    end

    def app_protocol
      AppUrl.protocol
    end
end
