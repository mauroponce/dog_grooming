module DepositProofs
  class RejectService
    def initialize(appointment:, actor:, reason:)
      @appointment = appointment
      @actor = actor
      @reason = reason.to_s.strip
    end

    def call
      raise "No se puede rechazar un turno confirmado o cancelado." if appointment.confirmed? || appointment.canceled?
      raise "Ingresá un motivo para rechazar el comprobante." if reason.blank?

      appointment.transaction do
        appointment.mark_deposit_rejected!(reason:, reviewed_by: actor)
        appointment.business.provider_events.create!(
          user: actor,
          event_type: "deposit_rejected",
          title: "Comprobante rechazado",
          body: "#{actor.email_address} rechazó la seña de #{appointment.customer_name}. Motivo: #{reason}.",
          metadata: {
            appointment_id: appointment.id,
            action_url: Rails.application.routes.url_helpers.admin_appointment_url(
              appointment,
              host: app_host,
              protocol: app_protocol
            )
          }
        )
      end

      appointment
    end

    private
      attr_reader :appointment, :actor, :reason

      def app_host
        AppUrl.host
      end

      def app_protocol
        AppUrl.protocol
      end
  end
end
