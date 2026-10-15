class SendCustomerBookingConfirmationJob < ApplicationJob
  self.enqueue_after_transaction_commit = true
  queue_as :default

  def perform(appointment)
    return unless appointment.confirmed?
    WhatsApp::AppointmentNotifications.call(appointment: appointment, purpose: "confirmation")

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
end
