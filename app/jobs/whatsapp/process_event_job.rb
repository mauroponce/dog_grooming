module WhatsApp
  class ProcessEventJob < ApplicationJob
    retry_on ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout, ActiveRecord::ConnectionNotEstablished, wait: :polynomially_longer, attempts: 5

    def perform(id)
      event = WhatsAppEvent.find(id)
      event.business.with_lock do
        event.lock!
        return if event.processed_at

        if event.kind.start_with?("status:")
          reconcile_status(event)
        else
          process_message(event)
        end
        event.update!(processed_at: Time.current, payload: {})
      end
    end

    private
      def reconcile_status(event)
        payload = event.payload
        scope = event.business.whatsapp_deliveries
        delivery = scope.find_by(provider_id: event.provider_id) || scope.find_by(dedupe_key: payload["biz_opaque_callback_data"])
        return unless delivery
        return if delivery.status == "sent" || (delivery.status == "failed" && payload["status"] == "sent")

        state = payload["status"] == "failed" ? "failed" : "sent"
        delivery.update!(provider_id: event.provider_id, status: state, accepted_at: delivery.accepted_at || Time.current, sent_at: state == "sent" ? Time.current : nil)
        SendAppointmentReminderJob.perform_later(delivery.appointment) if state == "failed" && delivery.purpose == "reminder" && delivery.appointment
      end

      def process_message(event)
        payload = event.payload
        phone = PhoneNumber.normalize(event.kind == "human" ? payload["to"] : payload["from"])
        return if phone.blank?

        contact = event.business.whatsapp_contacts.find_or_create_by!(phone: phone)
        timestamp = Time.at(payload["timestamp"].to_i).utc
        return if timestamp > 5.minutes.from_now || timestamp < 2.days.ago

        if event.kind == "human"
          contact.update!(last_human_at: [ timestamp, contact.last_human_at ].compact.max, paused_until: [ timestamp + 24.hours, contact.paused_until ].compact.max)
          return
        end
        contact.update!(last_inbound_at: [ timestamp, contact.last_inbound_at ].compact.max, name: payload["contact_name"].presence || contact.name)
        return if !WhatsApp.automation_enabled? || contact.paused? || !contact.window_open? || !event.business.booking_available?

        Bot.new(event: event, contact: contact).call
      end
  end
end
