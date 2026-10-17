class SendDueAppointmentRemindersJob < ApplicationJob
  queue_as :default

  def perform
    Appointment.confirmed.where(reminder_sent_at: nil, starts_at: Time.current..24.hours.from_now)
      .where.not(customer_email: [ nil, "" ]).find_each do |appointment|
      SendAppointmentReminderJob.perform_later(appointment)
    end
  end
end
