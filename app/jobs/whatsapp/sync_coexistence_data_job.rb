module WhatsApp
  class SyncCoexistenceDataJob < ApplicationJob
    def perform(id, generation)
      connection = WhatsAppConnection.find_by(id: id)
      return unless connection&.connected? && connection.coexistence? && connection.connected_at&.iso8601(6) == generation

      %w[smb_app_state_sync history].each do |type|
        claimed = connection.with_lock do
          return unless connection.connected? && connection.connected_at&.iso8601(6) == generation
          next false if connection.sync_metadata.key?(type)

          # These are one-shot operations. Persist the claim before the call;
          # after a timeout, never blindly replay a possibly accepted sync.
          connection.update!(sync_metadata: connection.sync_metadata.merge(type => { "state" => "requested", "requested_at" => Time.current.iso8601 }))
          true
        end
        next unless claimed

        begin
          result = CloudClient.new.post!("#{connection.phone_number_id}/smb_app_data", { messaging_product: "whatsapp", sync_type: type }, token: connection.access_token)
          raise CloudClient::UncertainDelivery if result["request_id"].blank?

          save_result(connection, generation, type, "state" => "accepted", "request_id" => result["request_id"])
        rescue CloudClient::Error => error
          state = error.is_a?(CloudClient::UncertainDelivery) ? "unknown" : "failed"
          save_result(connection, generation, type, "state" => state, "code" => error.code, "subcode" => error.subcode)
          connection.with_lock do
            connection.update!(authorization_failed_at: Time.current, automation_enabled: false) if error.authorization_error? && connection.connected_at&.iso8601(6) == generation
          end
          Rails.logger.warn("whatsapp_sync_#{state} connection_id=#{connection.id}")
        end
      end
    end

    private
      def save_result(connection, generation, type, result)
        connection.with_lock do
          return unless connection.connected_at&.iso8601(6) == generation

          previous = connection.sync_metadata.fetch(type, {})
          connection.update!(sync_metadata: connection.sync_metadata.merge(type => previous.merge(result)))
        end
      end
  end
end
