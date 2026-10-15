module WhatsApp
  class RecoverPendingJob < ApplicationJob
    def perform
      WhatsAppEvent.where(processed_at: nil).where("created_at < ?", 1.minute.ago).find_each { |event| ProcessEventJob.perform_later(event.id) }
      WhatsAppDelivery.where(status: "pending").where("created_at < ?", 1.minute.ago).find_each { |delivery| SendDeliveryJob.perform_later(delivery.id) }
      WhatsAppDelivery.where(status: "sending").where("updated_at < ?", 5.minutes.ago).update_all(status: "unknown", updated_at: Time.current)
      WhatsAppDelivery.where(status: "unknown", purpose: "reminder").joins(:appointment)
        .where(appointments: { reminder_sent_at: nil }).find_each do |delivery|
          SendAppointmentReminderJob.perform_later(delivery.appointment)
        end
    end
  end
end
