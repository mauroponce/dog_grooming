module WhatsApp
  class ProcessEventJob < ApplicationJob
    retry_on ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout, ActiveRecord::ConnectionNotEstablished, wait: :polynomially_longer, attempts: 5

    def perform(id)
      event = WhatsAppEvent.find(id)
      event.business.with_lock do
        event.lock!
        return if event.processed_at
        # Audit only: retain the minimal metadata, without restoring tokens,
        # marking the connection active, or invoking any automation.
        return event.update!(processed_at: Time.current) if event.kind == "account_reconnected"

        if event.kind == "account"
          connection = event.business.whatsapp_connection
          timestamp = Time.at(event.payload["timestamp"].to_i).utc
          if connection && connection.phone_number_id == event.phone_number_id && timestamp <= 5.minutes.from_now && timestamp.to_i >= (connection.connected_at || connection.created_at).to_i
            connection.update!(sync_metadata: connection.sync_metadata.merge("_offboarded_at" => timestamp.iso8601))
            connection.disconnect!
          end
        elsif event.kind.start_with?("sync:")
          connection = event.business.whatsapp_connection
          if connection && connection.phone_number_id == event.phone_number_id && connection.connected_at && event.created_at >= connection.connected_at
            type = event.kind.delete_prefix("sync:")
            metadata = connection.sync_metadata.fetch(type, {}).merge("received_at" => Time.current.iso8601)
            connection.update!(sync_metadata: connection.sync_metadata.merge(type => metadata))
          end
        elsif event.kind.start_with?("status:")
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
        return if delivery.phone_number_id.present? && delivery.phone_number_id != event.phone_number_id

        status = payload["status"]
        return unless status.in?(%w[sent delivered read failed])

        timestamp = Time.at(payload["timestamp"].to_i).utc
        timestamp = Time.current if timestamp > 5.minutes.from_now || timestamp < 1.year.ago
        attributes = { provider_id: event.provider_id, accepted_at: delivery.accepted_at || timestamp }
        column = { "sent" => :sent_at, "delivered" => :delivered_at, "read" => :read_at, "failed" => :failed_at }.fetch(status)
        attributes[column] = delivery.public_send(column) || timestamp
        attributes[:sent_at] = delivery.sent_at || timestamp if status.in?(%w[delivered read])
        attributes[:delivered_at] = delivery.delivered_at || timestamp if status == "read"
        if delivery.last_status_at.nil? || timestamp >= delivery.last_status_at
          attributes[:last_status_at] = timestamp
          attributes[:billing_metadata] = delivery.billing_metadata.merge(payload.slice("pricing", "conversation"))
        end
        ranks = { "pending" => 0, "sending" => 0, "unknown" => 0, "accepted" => 0, "failed" => 0, "sent" => 1, "delivered" => 2, "read" => 3 }
        if status != "failed" && ranks.fetch(status) >= ranks.fetch(delivery.status, 0)
          attributes[:status] = status
        elsif status == "failed" && !delivery.status.in?(%w[delivered read]) && (delivery.last_status_at.nil? || timestamp >= delivery.last_status_at)
          attributes[:status] = "failed"
        end
        delivery.update!(attributes)
        SendAppointmentReminderJob.perform_later(delivery.appointment) if attributes[:status] == "failed" && delivery.purpose == "reminder" && delivery.appointment
      end

      def process_message(event)
        connection = event.business.whatsapp_connection
        return if event.phone_number_id.present? && event.phone_number_id != connection&.phone_number_id

        payload = event.payload
        whatsapp_id = (event.kind == "human" ? payload["to"] : payload["from"]).to_s.delete("^0-9")
        phone = PhoneNumber.normalize(whatsapp_id)
        return if phone.blank?

        contact = event.business.whatsapp_contacts.find_or_create_by!(phone: phone)
        timestamp = Time.at(payload["timestamp"].to_i).utc
        return if timestamp > 5.minutes.from_now || timestamp < 2.days.ago

        if event.kind == "human"
          contact.update!(whatsapp_id: whatsapp_id.presence || contact.whatsapp_id, last_human_at: [ timestamp, contact.last_human_at ].compact.max, paused_until: [ timestamp + 24.hours, contact.paused_until ].compact.max)
          return
        end
        contact.update!(whatsapp_id: whatsapp_id.presence || contact.whatsapp_id, last_inbound_at: [ timestamp, contact.last_inbound_at ].compact.max, name: payload["contact_name"].presence || contact.name)
        return if !WhatsApp.automation_enabled?(event.business, recipient: phone) || contact.paused? || !contact.window_open? || !event.business.booking_available?

        Bot.new(event: event, contact: contact).call
      end
  end
end
