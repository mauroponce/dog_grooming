class ExpirePendingDepositBookingsJob < ApplicationJob
  queue_as :default

  def perform(appointment_id = nil)
    scope = Appointment.unscoped.where(status: %i[pending_deposit pending_payment]).includes(:business, :service)
    scope = scope.where(id: appointment_id) if appointment_id.present?

    scope.find_each do |appointment|
      next unless expired?(appointment)

      appointment.business.with_lock do
        appointment.reload
        next unless (appointment.pending_deposit? || appointment.pending_payment?) && expired?(appointment)

        appointment.update!(
          status: :expired,
          cancellation_reason: "Venció el plazo para completar el pago de la seña"
        )
        appointment.business.provider_events.create!(
          event_type: "deposit_deadline_expired",
          title: "Seña vencida",
          body: "Venció la seña de #{appointment.customer_name} para #{appointment.service.name}. El horario volvió a quedar disponible.",
          metadata: { appointment_id: appointment.id }
        )
      end
    end
  end

  private
    def expired?(appointment)
      deadline = appointment.payment_expires_at || appointment.created_at + appointment.service.deposit_payment_deadline_minutes.minutes
      deadline.past?
    end
end
