module DepositProofs
  class HistoryBuilder
    Event = Struct.new(:time, :actor, :title, :body, :tone, keyword_init: true)

    def initialize(appointment:)
      @appointment = appointment
    end

    def call
      events = []
      events << Event.new(
        time: appointment.created_at,
        actor: actor_for(appointment.source_label),
        title: "Reserva creada",
        body: "#{appointment.customer_name} reservó #{appointment.service.name}.",
        tone: :zinc
      )

      if appointment.deposit_submitted_at.present?
        events << Event.new(
          time: appointment.deposit_submitted_at,
          actor: appointment.customer_name,
          title: "Comprobante subido",
          body: "El cliente envió el archivo para revisión.",
          tone: :amber
        )
      end

      notification_events.each do |event|
        events << Event.new(
          time: event.created_at,
          actor: event.user&.email_address || "Sistema",
          title: event.title,
          body: event.body,
          tone: tone_for(event)
        )
      end

      notification_deliveries.each do |delivery|
        events << Event.new(
          time: delivery.sent_at || delivery.created_at,
          actor: "Email",
          title: "Email enviado al comercio",
          body: "#{delivery.template} · #{delivery.status}.",
          tone: :violet
        )
      end

      if appointment.deposit_reviewed_at.present?
        events << Event.new(
          time: appointment.deposit_reviewed_at,
          actor: appointment.deposit_reviewed_by&.email_address || "Revisión segura",
          title: appointment.deposit_status == "approved" ? "Comprobante aprobado" : "Comprobante rechazado",
          body: appointment.deposit_rejection_reason.presence || "La reserva quedó #{appointment.status_label.downcase}.",
          tone: appointment.deposit_status == "approved" ? :green : :rose
        )
      end

      events.sort_by { |event| event.time || Time.zone.at(0) }.reverse
    end

    private
      attr_reader :appointment

      def notification_events
        appointment.business.provider_events
          .where("metadata ->> 'appointment_id' = ?", appointment.id.to_s)
          .recent
          .limit(8)
      end

      def notification_deliveries
        appointment.notification_deliveries.order(created_at: :desc).limit(4)
      end

      def tone_for(event)
        case event.event_type
        when "deposit_approved" then :green
        when "deposit_rejected" then :rose
        when "deposit_receipt_submitted" then :amber
        else :violet
        end
      end

      def actor_for(label)
        label.presence || "Sistema"
      end
  end
end
