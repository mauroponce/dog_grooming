module WhatsApp
  class DeliveryHumanizer
    WAIT_SECONDS = 4..10
    MESSAGE_DELAY_MS = 4_000..9_000

    GREETINGS = [
      ->(business) { "Hola #{business.name}." },
      ->(business) { "Hola, #{business.name}." },
      ->(business) { "#{business.name}, tenés una actualización en Dog Grooming." }
    ].freeze

    EVENT_OPENINGS = {
      "pending_booking" => [
        "Entró una nueva reserva en tu agenda.",
        "Tenés un turno nuevo en Dog Grooming.",
        "Hay una reserva nueva para el centro."
      ],
      "deposit_proof" => [
        "Recibiste un comprobante para revisar.",
        "Hay una seña cargada pendiente de revisión.",
        "Un tutor subió un comprobante en Dog Grooming."
      ],
      "booking_cancelled" => [
        "Un cliente canceló un turno.",
        "Se registró una cancelación en tu agenda.",
        "Tenés una cancelación nueva en Dog Grooming."
      ],
      "waitlist_entry" => [
        "Se liberó un turno y hay personas en lista de espera para ese horario.",
        "Hay una lista de espera compatible con el turno liberado.",
        "Se detectaron clientes esperando un horario que acaba de liberarse."
      ]
    }.freeze

    ACTION_LINES = {
      "pending_booking" => [
        "Ver turno:",
        "Abrir reserva:",
        "Revisar en Dog Grooming:"
      ],
      "deposit_proof" => [
        "Abrir comprobante:",
        "Revisar seña:",
        "Ver comprobante:"
      ],
      "booking_cancelled" => [
        "Ver turno cancelado:",
        "Abrir detalle:",
        "Revisar la cancelación:"
      ],
      "waitlist_entry" => [
        "Ver lista de espera:",
        "Abrir clientes compatibles:",
        "Revisar lista filtrada:"
      ]
    }.freeze

    DAILY_TITLES = [
      "Resumen de hoy en Dog Grooming:",
      "Así viene tu día en Dog Grooming:",
      "Te dejo el resumen operativo de hoy:"
    ].freeze

    DAILY_ACTION_LINES = [
      "Abrir Dog Grooming:",
      "Ver el panel:",
      "Entrar al admin:"
    ].freeze

    def self.pause!
      return unless enabled?

      sleep(rand(WAIT_SECONDS))
    end

    def self.message_delay_ms
      rand(MESSAGE_DELAY_MS)
    end

    def self.owner_notification_text(business:, event:, template_key:, appointment:, action_url:)
      return deposit_proof_text(appointment:, action_url:) if template_key == "deposit_proof" && appointment.present?
      return confirmed_booking_text(appointment:, action_url:) if template_key == "pending_booking" && appointment&.confirmed?
      return cancelled_booking_text(appointment:, action_url:) if template_key == "booking_cancelled" && appointment.present?

      [
        greeting_for(business),
        event_line_for(event: event, template_key: template_key, appointment: appointment),
        appointment_details_for(appointment),
        action_url.present? ? "#{sample(ACTION_LINES.fetch(template_key, ACTION_LINES.fetch("pending_booking")))} #{action_url}" : nil
      ].compact.join("\n")
    end

    def self.daily_summary_text(business:, appointments_count:, pending_proofs_count:, follow_ups_count:, admin_url:)
      [
        greeting_for(business),
        sample(DAILY_TITLES),
        "#{appointments_count} turnos agendados.",
        "#{pending_proofs_count} comprobantes para revisar.",
        "#{follow_ups_count} seguimientos pendientes.",
        "#{sample(DAILY_ACTION_LINES)} #{admin_url}"
      ].join("\n")
    end

    def self.enabled?
      ENV.fetch("WHATSAPP_HUMANIZED_DELIVERY", "true") != "false"
    end

    def self.greeting_for(business)
      sample(GREETINGS).call(business)
    end

    def self.event_line_for(event:, template_key:, appointment:)
      opening = sample(openings_for(template_key, appointment))
      body = event.body.to_s.strip
      title = event.title.to_s.strip

      return opening if opening.present? && appointment.present?
      return "#{opening} #{body}".squish if opening.present? && body.present?
      return opening if opening.present?
      return "#{title}: #{body}" if title.present? && body.present?

      title.presence || body
    end

    def self.openings_for(template_key, appointment)
      EVENT_OPENINGS.fetch(template_key, [])
    end

    def self.confirmed_booking_text(appointment:, action_url:)
      date_and_time = appointment.starts_at.in_time_zone.strftime("%d/%m/%Y, %H:%Mhs")
      professional = appointment.employee_membership&.display_name.presence || "Sin asignar"
      whatsapp_number = appointment.customer_phone.to_s
      whatsapp_number = "+#{whatsapp_number}" unless whatsapp_number.start_with?("+")

      [
        "✅ Nuevo turno confirmado",
        "Cliente: #{appointment.customer_name} - #{whatsapp_number}",
        "Servicio: #{appointment.service&.name}",
        "Profesional: #{professional}",
        "Fecha y hora: #{date_and_time}",
        action_url.present? ? "Ver turno: #{action_url}" : nil
      ].compact.join("\n")
    end

    def self.cancelled_booking_text(appointment:, action_url:)
      date_and_time = appointment.starts_at.in_time_zone.strftime("%d/%m/%Y, %H:%Mhs")
      professional = appointment.employee_membership&.display_name.presence || "Sin asignar"
      whatsapp_number = appointment.customer_phone.to_s
      whatsapp_number = "+#{whatsapp_number}" unless whatsapp_number.start_with?("+")

      [
        "❌ Turno cancelado",
        "Cliente: #{appointment.customer_name} - #{whatsapp_number}",
        "Servicio: #{appointment.service&.name}",
        "Profesional: #{professional}",
        "Fecha y hora: #{date_and_time}",
        action_url.present? ? "Ver turno: #{action_url}" : nil
      ].compact.join("\n")
    end

    def self.appointment_details_for(appointment)
      return nil if appointment.blank?

      lines = [
        "Clienta: #{appointment.customer_name}",
        "Servicio: #{appointment.service&.name}",
        "Fecha: #{appointment.customer_starts_at_label}",
        appointment.employee_membership&.name.present? ? "Profesional: #{appointment.employee_membership.name}" : nil
      ].compact

      if appointment.deposit_required?
        lines << "Seña: #{appointment.formatted_deposit_amount}"
      end

      lines.join("\n")
    end

    def self.deposit_proof_text(appointment:, action_url:)
      [
        "📥 Nuevo comprobante de #{appointment.customer_name} (#{appointment.formatted_deposit_amount}) para #{appointment.customer_starts_at_label}.",
        "Servicio: #{appointment.service&.name}",
        action_url.present? ? "Ver comprobante y confirmar: #{action_url}" : nil
      ].compact.join("\n")
    end

    def self.sample(values)
      values.sample
    end
  end
end
