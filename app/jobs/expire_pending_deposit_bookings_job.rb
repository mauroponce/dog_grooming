class ExpirePendingDepositBookingsJob < ApplicationJob
  queue_as :default

  def perform
    Appointment.pending_deposit.includes(:business, :service).find_each do |appointment|
      next unless expired?(appointment)

      appointment.update!(
        status: :expired,
        cancellation_reason: "Venció el plazo para subir el comprobante de seña"
      )
      appointment.business.provider_events.create!(
        event_type: "deposit_deadline_expired",
        title: "Seña vencida",
        body: "Venció la seña de #{appointment.customer_name} para #{appointment.service.name}. El horario volvió a quedar disponible.",
        metadata: { appointment_id: appointment.id }
      )
    end
  end

  private
    def expired?(appointment)
      deadline = appointment.created_at + appointment.service.deposit_payment_deadline_minutes.minutes
      deadline.past?
    end
end
