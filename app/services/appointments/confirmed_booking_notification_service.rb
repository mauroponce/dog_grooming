module Appointments
  class ConfirmedBookingNotificationService
    def self.call(appointment)
      new(appointment).call
    end

    def initialize(appointment)
      @appointment = appointment
    end

    def call
      appointment.business.provider_events.create!(
        event_type: "new_booking",
        title: "Nuevo turno confirmado",
        body: "#{appointment.customer_name} confirmó #{appointment.service.name} para #{appointment.customer_starts_at_label}.",
        metadata: {
          appointment_id: appointment.id,
          appointment_ids: appointment.appointment_payment&.appointment_ids,
          appointment_payment_id: appointment.appointment_payment&.id,
          action_url: admin_appointment_url
        }.compact
      )
    end

    private
      attr_reader :appointment

      def admin_appointment_url
        Rails.application.routes.url_helpers.admin_appointment_url(
          appointment,
          host: AppUrl.host,
          protocol: AppUrl.protocol
        )
      end
  end
end
