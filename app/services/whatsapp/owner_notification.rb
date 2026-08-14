module WhatsApp
  class OwnerNotification
    EVENT_TEMPLATES = {
      "new_booking" => "pending_booking",
      "deposit_receipt_submitted" => "deposit_proof",
      "customer_uploaded_proof" => "deposit_proof",
      "customer_replaced_proof" => "deposit_proof",
      "customer_cancelled_booking" => "booking_cancelled",
      "waitlist_released_slot" => "waitlist_entry"
    }.freeze

    TEMPLATE_PREFERENCES = {
      "pending_booking" => :whatsapp_notify_pending_bookings?,
      "deposit_proof" => :whatsapp_notify_deposit_proofs?,
      "booking_cancelled" => :whatsapp_notify_cancellations?,
      "waitlist_entry" => :whatsapp_notify_cancellations?,
      "daily_summary" => :whatsapp_notify_daily_summary?
    }.freeze

    def self.supported_event_type?(event_type)
      EVENT_TEMPLATES.key?(event_type.to_s)
    end

    def initialize(event, client: WhatsApp::EvolutionClient.new)
      @event = event
      @client = client
      @business = event.business
    end

    def deliver
      return unless enabled_provider?
      return unless self.class.supported_event_type?(event.event_type)
      return unless business.owner_whatsapp_notifications_ready?
      return unless template_enabled?

      delivery = create_delivery!("queued")
      delivery_context = build_delivery_context
      WhatsApp::DeliveryHumanizer.pause!
      presence_response = send_presence(delivery_context)
      response = client.send_text(
        number: business.owner_whatsapp_recipient,
        text: delivery_context.fetch(:message),
        delay: delivery_context.fetch(:send_delay_ms)
      )

      if response[:success]
        delivery.update!(
          status: "sent",
          sent_at: Time.current,
          provider_message_id: provider_message_id(response[:body]),
          payload: delivery_payload(response, delivery_context, presence_response)
        )
      else
        delivery.update!(
          status: "failed",
          error_message: response[:error].presence || "Evolution API respondió con estado #{response[:status]}",
          payload: delivery_payload(response, delivery_context, presence_response)
        )
      end
    end

    private
      attr_reader :event, :client, :business

      def enabled_provider?
        ENV.fetch("WHATSAPP_PROVIDER", "").to_s == "evolution"
      end

      def template_key
        EVENT_TEMPLATES.fetch(event.event_type)
      end

      def template_enabled?
        preference = TEMPLATE_PREFERENCES.fetch(template_key)
        business.public_send(preference)
      end

      def create_delivery!(status)
        NotificationDelivery.create!(
          business: business,
          appointment: appointment,
          channel: "whatsapp_evolution",
          recipient: business.owner_whatsapp_recipient,
          template: template_key,
          status: status,
          payload: {
            provider_event_id: event.id,
            provider_event_type: event.event_type
          }
        )
      end

      def build_delivery_context
        {
          message: message,
          send_delay_ms: WhatsApp::DeliveryHumanizer.message_delay_ms
        }
      end

      def send_presence(delivery_context)
        return unless client.respond_to?(:send_presence)

        client.send_presence(
          number: business.owner_whatsapp_recipient,
          presence: "composing",
          delay: delivery_context.fetch(:send_delay_ms)
        )
      rescue StandardError => error
        { success: false, status: nil, error: "#{error.class}: #{error.message}" }
      end

      def message
        WhatsApp::DeliveryHumanizer.owner_notification_text(
          business: business,
          event: event,
          template_key: template_key,
          appointment: appointment,
          action_url: action_url
        )
      end

      def action_url
        @action_url ||= begin
          url = Admin::NotificationItem.new(event).action_url
          if url.blank?
            nil
          elsif url.match?(/\Ahttps?:\/\//)
            url
          else
            "#{app_protocol}://#{app_host}#{url}"
          end
        end
      end

      def appointment
        @appointment ||= begin
          appointment_id = event.metadata["appointment_id"].presence
          business.appointments.find_by(id: appointment_id) if appointment_id.present?
        end
      end

      def provider_message_id(body)
        body.dig("key", "id").presence ||
          body.dig("message", "key", "id").presence ||
          body.dig("data", "key", "id").presence ||
          body["id"].presence
      end

      def delivery_payload(response, delivery_context, presence_response)
        {
          provider_event_id: event.id,
          provider_event_type: event.event_type,
          send_delay_ms: delivery_context[:send_delay_ms],
          presence_status: presence_response&.dig(:status),
          status: response[:status],
          response: response[:sanitized_body]
        }.compact
      end

      def app_host
        AppUrl.host
      end

      def app_protocol
        AppUrl.protocol
      end
  end
end
