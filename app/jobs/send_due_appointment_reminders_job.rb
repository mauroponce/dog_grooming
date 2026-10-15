class SendDueAppointmentRemindersJob < ApplicationJob
  queue_as :default

  def perform
    Appointment.confirmed.where(reminder_sent_at: nil)
      .where(starts_at: Time.current..25.hours.from_now).includes(:business).find_each do |appointment|
        due_at = appointment.starts_at - appointment.business.whatsapp_reminder_hours.hours
        next unless due_at <= Time.current && due_at > 30.minutes.ago

        SendAppointmentReminderJob.perform_later(appointment)
      end
  end
end
