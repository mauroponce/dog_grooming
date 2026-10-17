class SendAppointmentReminderJob < ApplicationJob
  self.enqueue_after_transaction_commit = true
  queue_as :default
  retry_on Net::SMTPServerBusy, Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(appointment)
    appointment.with_lock do
      return unless appointment.confirmed? && appointment.starts_at.future? && appointment.starts_at <= 24.hours.from_now
      return if appointment.reminder_sent_at.present? || appointment.customer_email.blank?

      AppointmentMailer.customer_reminder(appointment).deliver_now
      appointment.update!(reminder_sent_at: Time.current)
      appointment.notification_deliveries.create!(
        business: appointment.business,
        channel: "email",
        recipient: appointment.customer_email,
        template: "customer_reminder",
        status: "sent",
        sent_at: Time.current
      )
    end
  end
end
