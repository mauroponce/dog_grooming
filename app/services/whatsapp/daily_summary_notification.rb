module WhatsApp
  class DailySummaryNotification
    def initialize(business, client: WhatsApp::EvolutionClient.new)
      @business = business
      @client = client
      @today = Time.zone.today
    end

    def deliver
      return unless WhatsApp::AutomatedNotifications.enabled?
      return unless enabled_provider?
      return unless business.owner_whatsapp_notifications_ready?
      return unless business.whatsapp_notify_daily_summary?

      delivery = NotificationDelivery.create!(
        business: business,
        channel: "whatsapp_evolution",
        recipient: business.owner_whatsapp_recipient,
        template: "daily_summary",
        status: "queued",
        payload: { date: today.iso8601 }
      )
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
      attr_reader :business, :client, :today

      def enabled_provider?
        ENV.fetch("WHATSAPP_PROVIDER", "").to_s == "evolution"
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
        WhatsApp::DeliveryHumanizer.daily_summary_text(
          business: business,
          appointments_count: appointments_count,
          pending_proofs_count: pending_proofs_count,
          follow_ups_count: follow_ups_count,
          admin_url: admin_url
        )
      end

      def appointments_count
        @appointments_count ||= business.appointments.where(starts_at: today.all_day).count
      end

      def pending_proofs_count
        @pending_proofs_count ||= business.appointments.awaiting_deposit_review.count
      end

      def follow_ups_count
        @follow_ups_count ||= business.customer_reminders.pending.where(reminder_type: "service_follow_up").count
      end

      def provider_message_id(body)
        body.dig("key", "id").presence ||
          body.dig("message", "key", "id").presence ||
          body.dig("data", "key", "id").presence ||
          body["id"].presence
      end

      def delivery_payload(response, delivery_context, presence_response)
        {
          date: today.iso8601,
          send_delay_ms: delivery_context[:send_delay_ms],
          presence_status: presence_response&.dig(:status),
          status: response[:status],
          response: response[:sanitized_body]
        }.compact
      end

      def admin_url
        Rails.application.routes.url_helpers.admin_root_url(
          host: app_host,
          protocol: app_protocol
        )
      end

      def app_host
        AppUrl.host
      end

      def app_protocol
        AppUrl.protocol
      end
  end
end
