class SendDueAppointmentRemindersJob < ApplicationJob
  queue_as :default

  def perform
    Appointment.confirmed
      .where(reminder_sent_at: nil)
      .where.not(customer_email: [ nil, "" ])
      .where(starts_at: 24.hours.from_now..(24.hours + 30.minutes).from_now)
      .find_each { |appointment| SendAppointmentReminderJob.perform_later(appointment) }
  end
end
