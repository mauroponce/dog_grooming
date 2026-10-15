module WhatsApp
  class AppointmentNotifications
    TRIAL_LIMIT = 20
    EXHAUSTED_MESSAGE = "Agotaste los 20 recordatorios de prueba de WhatsApp del Plan PRO. Tus reservas automáticas y señas siguen funcionando con normalidad. Para desbloquear recordatorios ilimitados por WhatsApp, aboná tu primer mes de Plan PRO.".freeze

    def self.call(appointment:, purpose:)
      new(appointment, purpose).call
    end

    def initialize(appointment, purpose)
      @appointment, @purpose, @business = appointment, purpose, appointment.business
    end

    def call
      @business.with_lock do
        return false unless @appointment.reload.confirmed? && @business.access_active?
        return false unless @business.whatsapp_connection&.connected?
        existing = @business.whatsapp_deliveries.find_by(dedupe_key: "#{@purpose}:#{@appointment.id}:#{@appointment.starts_at.to_i}")
        return !existing.status.in?(%w[failed skipped unknown]) if existing

        contact = @business.whatsapp_contacts.find_by(phone: @appointment.customer_phone)
        # A WhatsApp booking starts with an inbound conversation. Arbitrary
        # phone numbers submitted on the public web are never opted in silently.
        return false unless contact

        subscription = @business.subscription
        trial = !subscription&.paid? && @business.trial_active?
        if @purpose == "reminder"
          return false unless contact.opted_in_at
          return false unless subscription&.pro? && (subscription.paid? || trial)

          if trial && trial_count >= TRIAL_LIMIT
            notify_exhausted!
            return false
          end
        end

        template_needed = !contact.window_open? || @purpose == "reminder"
        return false if template_needed && (!subscription&.pro? || !@business.whatsapp_connection.templates_approved?)

        delivery = WhatsAppDelivery.enqueue!(business: @business, key: "#{@purpose}:#{@appointment.id}:#{@appointment.starts_at.to_i}", purpose: @purpose,
          appointment: @appointment, trial_reminder: trial && @purpose == "reminder", payload: message_payload(template_needed))
        notify_exhausted! if trial && @purpose == "reminder" && trial_count >= TRIAL_LIMIT
        !delivery.status.in?(%w[failed skipped])
      end
    end

    private
      def trial_count
        @business.whatsapp_deliveries.where(trial_reminder: true).where.not(status: %w[failed skipped]).count
      end

      def notify_exhausted!
        return if @business.provider_events.exists?(event_type: "whatsapp_trial_exhausted")

        @business.provider_events.create!(event_type: "whatsapp_trial_exhausted", title: "Recordatorios WhatsApp de prueba agotados", body: EXHAUSTED_MESSAGE)
      end

      def message_payload(template_needed)
        base = { to: @appointment.customer_phone.delete_prefix("+") }
        if template_needed
          connection = @business.whatsapp_connection
          name = @purpose == "reminder" ? connection.reminder_template : connection.confirmation_template
          base.merge(type: "template", template: { name: name, language: { code: connection.template_language }, components: [ { type: "body", parameters: [ @appointment.pet&.name.presence || "tu mascota", @appointment.service.name, @appointment.customer_starts_at_label, @business.name ].map { |value| { type: "text", text: value } } } ] })
        else
          base.merge(type: "text", text: { body: "✅ Turno confirmado para #{@appointment.pet&.name.presence || 'tu mascota'} en #{@business.name}. #{@appointment.service.name}: #{@appointment.customer_starts_at_label}. #{@appointment.customer_portal_booking_url}" })
        end
      end
  end
end
