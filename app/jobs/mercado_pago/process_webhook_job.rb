module MercadoPago
  class ProcessWebhookJob < ApplicationJob
    queue_as :default

    def perform(payload:, headers: {}, params: {})
      data = payload.to_h
      request_params = params.to_h
      return unless payment_event?(data, request_params)

      remote_payment = fetch_remote_payment!(data, request_params)
      appointment_payment = find_appointment_payment(remote_payment, request_params)
      return if appointment_payment.blank?
      return if appointment_payment.approved?

      case remote_payment["status"].to_s
      when "approved"
        approve_payment!(appointment_payment, remote_payment)
      when "rejected", "cancelled", "canceled"
        appointment_payment.mark_failed!(status: remote_payment["status"], payload: remote_payment)
        mark_appointments_failed!(appointment_payment)
      end
    end

    private
      def payment_event?(payload, params)
        event_type = payload["type"].presence || params["type"].presence || params["topic"].presence
        event_type.to_s == "payment"
      end

      def fetch_remote_payment!(payload, params)
        payment_id = payload.dig("data", "id").presence ||
          params.dig("data", "id").presence ||
          params["data.id"].presence ||
          params["id"].presence
        raise ArgumentError, "Mercado Pago webhook sin payment id." if payment_id.blank?

        connection = connection_for_payload(payload, params)
        MercadoPago::Client.for_connection(connection).fetch_payment!(payment_id)
      end

      def connection_for_payload(payload, params)
        reference = params["reference"].presence || payload["external_reference"].presence
        payment = AppointmentPayment.find_by(external_reference: reference) if reference.present?
        return payment.business.mercado_pago_connection if payment&.business&.mercado_pago_connection.present?

        user_id = payload["user_id"].presence || params["user_id"].presence
        connection = MercadoPagoConnection.connected.find_by(mercado_pago_user_id: user_id.to_s) if user_id.present?
        connection || MercadoPagoConnection.connected.first || raise(MercadoPago::Client::MissingAccessToken, "No se encontró la conexión de Mercado Pago.")
      end

      def find_appointment_payment(remote_payment, params)
        reference = remote_payment["external_reference"].presence || params["reference"].presence
        return AppointmentPayment.find_by(external_reference: reference) if reference.present?

        AppointmentPayment.find_by(provider_payment_id: remote_payment["id"].to_s)
      end

      def approve_payment!(appointment_payment, remote_payment)
        confirmed_appointments = []
        appointment_payment.transaction do
          appointment_payment.mark_approved!(payload: remote_payment)
          appointment_payment.appointments.find_each do |appointment|
            next if appointment.confirmed?

            appointment.mark_deposit_approved!(reviewed_by: nil)
            confirmed_appointments << appointment
          end
          confirmed_appointments.each { |appointment| Appointments::ConfirmedBookingNotificationService.call(appointment) }
        end

        confirmed_appointments.each { |appointment| SendCustomerBookingConfirmationJob.perform_later(appointment) }
      end

      def mark_appointments_failed!(appointment_payment)
        appointment_payment.appointments.find_each do |appointment|
          next unless appointment.mercado_pago_payment_pending?

          appointment.update!(
            status: :canceled,
            deposit_status: "failed",
            canceled_at: Time.current,
            canceled_by: "system",
            cancellation_reason: "Mercado Pago informó que el pago no fue aprobado.",
            canceled_late: false
          )
        end
      end
  end
end
