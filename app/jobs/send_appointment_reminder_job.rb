class SendAppointmentReminderJob < ApplicationJob
  queue_as :default

  def perform(appointment)
    return unless appointment.confirmed? && appointment.starts_at.future?
    return if WhatsApp::AppointmentNotifications.call(appointment: appointment, purpose: "reminder")
    appointment.with_lock do
      appointment.reload
      return if appointment.canceled? || appointment.reminder_sent_at.present?
      return if appointment.customer_email.blank?

      AppointmentMailer.customer_reminder(appointment).deliver_now
      appointment.update!(reminder_sent_at: Time.current)
    end
  end
end
