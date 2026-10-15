module WhatsApp
  class SendDeliveryJob < ApplicationJob
    def perform(id)
      return unless WhatsApp.automation_enabled?

      delivery = WhatsAppDelivery.find(id)
      connection = delivery.business.whatsapp_connection
      return unless WhatsApp.automation_enabled?(delivery.business)

      delivery.business.with_lock do
        delivery.lock!
        return unless delivery.status == "pending"
        if connection.coexistence? && (delivery.payload["type"] == "template" || delivery.phone_number_id != connection.phone_number_id)
          return delivery.update!(status: "skipped")
        end
        return delivery.update!(status: "skipped") unless delivery.business.access_active?
        if delivery.purpose.in?(%w[reminder confirmation]) && delivery.appointment.nil?
          return delivery.update!(status: "skipped")
        end
        if delivery.appointment && (!delivery.appointment.confirmed? || delivery.appointment.starts_at.past?)
          return delivery.update!(status: "skipped")
        end
        if delivery.appointment && delivery.dedupe_key != "#{delivery.purpose}:#{delivery.appointment.id}:#{delivery.appointment.starts_at.to_i}"
          return delivery.update!(status: "skipped")
        end
        subscription = delivery.business.subscription
        if delivery.purpose == "reminder" && !(subscription&.pro? && (subscription.paid? || delivery.business.trial_active?))
          delivery.update!(status: "skipped")
          SendAppointmentReminderJob.perform_later(delivery.appointment)
          return
        end
        if delivery.purpose == "reply"
          contact = delivery.business.whatsapp_contacts.find_by(phone: PhoneNumber.normalize(delivery.payload["to"]))
          return delivery.update!(status: "skipped") unless contact&.window_open? && !contact.paused?
        end
        unless delivery.payload["type"] == "template"
          contact = delivery.business.whatsapp_contacts.find_by(phone: PhoneNumber.normalize(delivery.payload["to"]))
          return delivery.update!(status: "skipped") unless contact&.window_open?
        end
        delivery.update!(status: "sending", attempts: delivery.attempts + 1)
      end

      response = CloudClient.new(connection: connection).send_message!(delivery.payload.merge("messaging_product" => "whatsapp", "biz_opaque_callback_data" => delivery.dedupe_key))
      provider_id = response.dig("messages", 0, "id")
      raise CloudClient::UncertainDelivery if provider_id.blank?

      WhatsAppDelivery.where(id: delivery.id, status: "sending").update_all(status: "accepted", accepted_at: Time.current, provider_id: provider_id, updated_at: Time.current)
    rescue CloudClient::RetryableError
      if delivery.attempts < 3
        delivery.update!(status: "pending")
        self.class.set(wait: 1.minute).perform_later(id)
      else
        failed!(delivery)
      end
    rescue CloudClient::UncertainDelivery, Net::OpenTimeout, Errno::ECONNREFUSED
      WhatsAppDelivery.where(id: delivery.id, status: "sending").update_all(status: "unknown", updated_at: Time.current)
      SendAppointmentReminderJob.perform_later(delivery.appointment) if delivery.purpose == "reminder" && delivery.appointment
      Rails.logger.warn("whatsapp_delivery_unknown delivery_id=#{id}")
    rescue CloudClient::Error => error
      connection&.update!(authorization_failed_at: Time.current, automation_enabled: false) if error.authorization_error?
      failed!(delivery)
      Rails.logger.warn("whatsapp_delivery_failed delivery_id=#{id}")
    end

    private
      def failed!(delivery)
        delivery.update!(status: "failed")
        SendAppointmentReminderJob.perform_later(delivery.appointment) if delivery.purpose == "reminder" && delivery.appointment
      end
  end
end
