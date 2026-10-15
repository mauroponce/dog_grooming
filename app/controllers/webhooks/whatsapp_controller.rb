require "openssl"

module Webhooks
  class WhatsAppController < ActionController::Base
    # Only this external POST uses Meta's signature in place of a CSRF token.
    skip_before_action :verify_authenticity_token, only: :create

    def verify
      token = ENV["WHATSAPP_WEBHOOK_VERIFY_TOKEN"].to_s
      if token.present? && params["hub.mode"] == "subscribe" && ActiveSupport::SecurityUtils.secure_compare(token, params["hub.verify_token"].to_s)
        render plain: params["hub.challenge"].to_s
      else
        head :forbidden
      end
    end

    def create
      secret = ENV["META_APP_SECRET"].to_s
      signature = request.headers["X-Hub-Signature-256"].to_s
      expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, request.raw_post)}"
      return head :unauthorized unless secret.present? && ActiveSupport::SecurityUtils.secure_compare(expected, signature)

      payload = JSON.parse(request.raw_post)
      return head :bad_request unless valid_payload?(payload)

      WhatsAppEvent.transaction do
        Array(payload["entry"]).each do |entry|
          Array(entry["changes"]).each do |change|
            value = change.fetch("value", {})
            if change["field"] == "account_update"
              persist_account_change(entry, value)
              next
            end
            connection = WhatsAppConnection.find_by(phone_number_id: value.dig("metadata", "phone_number_id"), waba_id: entry["id"], disconnected_at: nil)
            unless connection
              Rails.logger.info("whatsapp_webhook_unmapped")
              next
            end

            if change["field"].in?(%w[history smb_app_state_sync])
              # Complete required synchronization without retaining historical
              # conversations/contacts or feeding old messages to the chatbot.
              persist(connection, { "id" => Digest::SHA256.hexdigest(change.to_json), "timestamp" => Time.current.to_i.to_s }, "sync:#{change['field']}")
            elsif change["field"] == "smb_message_echoes"
              Array(value["message_echoes"]).each { |message| persist(connection, message.slice("id", "to", "timestamp"), "human") }
            elsif change["field"] == "messages"
              Array(value["messages"]).each do |message|
                name = Array(value["contacts"]).find { |contact| contact["wa_id"] == message["from"] }&.dig("profile", "name")
                persist(connection, message.merge("contact_name" => name), "inbound")
              end
              Array(value["statuses"]).each { |status| persist(connection, status, "status:#{status['status']}") }
            end
          end
        end
      end
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private
      def persist_account_change(entry, value)
        event = value["event"]
        return persist_reconnection(entry, value) if event == "ACCOUNT_RECONNECTED"

        return unless event.in?(%w[PARTNER_APP_UNINSTALLED PARTNER_REMOVED ACCOUNT_DELETED ACCOUNT_OFFBOARDED])
        return if event == "PARTNER_APP_UNINSTALLED" && value.dig("waba_info", "partner_app_id") != ENV["META_APP_ID"]

        WhatsAppConnection.where(waba_id: entry["id"], disconnected_at: nil).find_each do |connection|
          message = { "id" => "account:#{entry['id']}:#{event}:#{entry['time']}", "timestamp" => entry["time"].to_s, "event" => event }
          persist(connection, message, "account")
        end
      end

      def persist_reconnection(entry, value)
        waba_id = entry["id"].to_s
        phone_number_id = value.dig("metadata", "phone_number_id").presence || value["phone_number_id"].presence
        phone_number_id = phone_number_id.to_s if phone_number_id
        timestamp = entry["time"].to_s
        valid = waba_id.match?(/\A\d+\z/) && timestamp.match?(/\A\d+\z/) && timestamp.to_i.positive? &&
          (phone_number_id.nil? || phone_number_id.match?(/\A\d+\z/))

        candidates = if valid
          scope = WhatsAppConnection.where(waba_id: waba_id)
          scope = scope.where(phone_number_id: phone_number_id) if phone_number_id
          scope.limit(2).to_a
        else
          []
        end

        if candidates.one?
          connection = candidates.sole
          identifier = reconnection_identifier(waba_id, connection.phone_number_id, timestamp)
          persist(connection, { "id" => identifier, "event" => "ACCOUNT_RECONNECTED", "timestamp" => timestamp, "waba_id" => waba_id }, "account_reconnected")
        else
          # Do not fall back to an unrelated phone or guess among tenants.
          # Duplicate deliveries share this diagnostic ID without creating
          # tenant records or triggering any job or connection side effect.
          reason = !valid ? "invalid_identifiers" : candidates.empty? ? "unknown_connection" : "ambiguous_connection"
          Rails.logger.warn({ event: "whatsapp_account_reconnected_unmapped", account_event: "ACCOUNT_RECONNECTED",
            event_id: reconnection_identifier(waba_id, phone_number_id, timestamp), reason: reason,
            waba_id: waba_id.match?(/\A\d+\z/) ? waba_id : nil,
            phone_number_id: phone_number_id&.match?(/\A\d+\z/) ? phone_number_id : nil,
            timestamp: timestamp.match?(/\A\d+\z/) ? timestamp : nil }.to_json)
        end
      end

      def reconnection_identifier(waba_id, phone_number_id, timestamp)
        "account:#{Digest::SHA256.hexdigest([ waba_id, phone_number_id, 'ACCOUNT_RECONNECTED', timestamp ].to_json)}"
      end

      def valid_payload?(payload)
        return false unless payload.is_a?(Hash) && payload["object"] == "whatsapp_business_account" && payload["entry"].is_a?(Array)

        payload["entry"].all? do |entry|
          entry.is_a?(Hash) && entry["changes"].is_a?(Array) && entry["changes"].all? do |change|
            next false unless change.is_a?(Hash) && change["value"].is_a?(Hash)

            value = change["value"]
            next false if value["metadata"] && !value["metadata"].is_a?(Hash)

            %w[messages statuses message_echoes contacts].all? do |key|
              !value.key?(key) || (value[key].is_a?(Array) && value[key].all? { |item| item.is_a?(Hash) })
            end
          end
        end
      end

      def persist(connection, message, kind)
        return if message["id"].blank?

        # Store only fields needed for routing, not media or conversation history.
        keys = case kind
        when "human" then %w[id to timestamp]
        when "account_reconnected" then %w[id event timestamp waba_id]
        else %w[id from to timestamp text interactive contact_name status biz_opaque_callback_data pricing conversation event]
        end
        data = message.slice(*keys)
        event = connection.business.whatsapp_events.create_or_find_by!(provider_id: message.fetch("id"), kind: kind) do |record|
          record.payload = data
          record.phone_number_id = connection.phone_number_id
        end
        # A retry also repairs a commit followed by a failed enqueue.
        WhatsApp::ProcessEventJob.perform_later(event.id) if !event.previously_new_record? && event.processed_at.nil?
        Rails.logger.info("whatsapp_webhook_received business_id=#{connection.business_id} event_id=#{event.id}")
      end
  end
end
