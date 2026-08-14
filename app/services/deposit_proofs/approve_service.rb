module DepositProofs
  class ApproveService
    def initialize(appointment:, actor:)
      @appointment = appointment
      @actor = actor
    end

    def call
      raise "No se puede confirmar un turno cancelado." if appointment.canceled?

      notify_customer = !appointment.confirmed?
      appointment.transaction do
        appointment.mark_deposit_approved!(reviewed_by: actor)
        appointment.business.provider_events.create!(
          user: actor,
          event_type: "deposit_approved",
          title: "Comprobante aprobado",
          body: "#{actor.email_address} aprobó la seña de #{appointment.customer_name} para #{appointment.service.name}.",
          metadata: {
            appointment_id: appointment.id,
            action_url: Rails.application.routes.url_helpers.admin_appointment_url(
              appointment,
              host: app_host,
              protocol: app_protocol
            ),
            whatsapp_url: WhatsApp::ProofMessageBuilder.new(appointment).confirmed_url
          }
        )
        Appointments::ConfirmedBookingNotificationService.call(appointment) if notify_customer
      end

      SendCustomerBookingConfirmationJob.perform_later(appointment) if notify_customer
      appointment
    end

    private
      attr_reader :appointment, :actor

      def app_host
        AppUrl.host
      end

      def app_protocol
        AppUrl.protocol
      end
  end
end
