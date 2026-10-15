module MercadoPago
  class ApproveBookingPayment
    def self.call(payment:, payload:)
      payment.business.with_lock do
        payment.lock!
        return if payment.approved?
        raise ArgumentError, "El pago todavía no está aprobado" unless payload["status"] == "approved"
        raise ArgumentError, "Referencia de pago inválida" unless payload["external_reference"] == payment.external_reference
        amount = (BigDecimal(payload.fetch("transaction_amount").to_s) * 100).to_i
        raise ArgumentError, "Importe de pago inválido" unless amount == payment.amount_cents && payload["currency_id"] == payment.currency
        collector = payment.business.mercado_pago_connection&.mercado_pago_user_id
        raise ArgumentError, "Cuenta de cobro inválida" if collector.present? && payload["collector_id"].to_s != collector

        appointments = payment.appointments.lock.to_a
        payment.mark_approved!(payload: payload)
        late = appointments.any? { |appointment| appointment.terminal_status? || (appointment.payment_expires_at && appointment.payment_expires_at <= Time.current) }
        if late
          payment.business.provider_events.create!(event_type: "late_payment", title: "Pago recibido fuera de plazo", body: "El pago de Mercado Pago requiere revisión o reintegro; no se confirmó el horario liberado.", metadata: { appointment_payment_id: payment.id })
          return
        end
        appointments.each do |appointment|
          next if appointment.confirmed?

          appointment.mark_deposit_approved!(reviewed_by: nil)
          Appointments::ConfirmedBookingNotificationService.call(appointment)
          SendCustomerBookingConfirmationJob.perform_later(appointment)
        end
      end
    end
  end
end
