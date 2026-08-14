module Ai
  class AppointmentReplyGenerator
    def initialize(appointment:)
      @appointment = appointment
      @business = appointment.business
    end

    def call(context: nil)
      payload = GeminiClient.chat_json(
        system: system_prompt,
        messages: [ { role: "user", content: user_prompt(context) } ],
        temperature: 0.65,
        max_tokens: 900,
        feature: "appointment_reply_generator",
        business: business
      )

      normalize_variants(payload["variants"])
    end

    private
      attr_reader :appointment, :business

      def system_prompt
        <<~PROMPT
          Sos una asistente experta en atención por WhatsApp para peluquerías caninas y groomers.
          Generá respuestas listas para enviar, claras, empáticas y sin prometer cosas que no figuran en los datos.
          Respondé exclusivamente JSON válido:
          {
            "variants": [
              {"tone": "Formal", "text": "..."},
              {"tone": "Amigable", "text": "..."},
              {"tone": "Corta", "text": "..."}
            ]
          }
        PROMPT
      end

      def user_prompt(context)
        <<~PROMPT
          Negocio: #{business.name}
          Cliente: #{appointment.customer_name}
          WhatsApp cliente: #{appointment.customer_phone}
          Servicio: #{appointment.service.name}
          Fecha: #{appointment.customer_starts_at_label}
          Estado del turno: #{appointment.status_label}
          Estado de seña: #{appointment.deposit_status_label}
          Dirección: #{business.public_location}
          Notas internas/contexto puntual: #{context.presence || appointment.notes.presence || "Sin notas"}

          Necesito 3 textos: uno formal, uno súper amigable/afectivo del rubro grooming y uno corto con emojis.
        PROMPT
      end

      def normalize_variants(values)
        variants = Array(values).filter_map do |entry|
          text = entry["text"].to_s.strip
          next if text.blank?

          { tone: entry["tone"].to_s.presence || "Respuesta", text: text }
        end

        variants.presence || fallback_variants
      end

      def fallback_variants
        [
          { tone: "Formal", text: "Hola #{appointment.customer_name}, te escribimos de #{business.name} por tu turno de #{appointment.service.name} el #{appointment.customer_starts_at_label}. ¿Podés confirmarnos si vas a asistir?" },
          { tone: "Amigable", text: "Hola #{appointment.customer_name}, ¿cómo estás? Te escribimos de #{business.name} para confirmar tu turno de #{appointment.service.name} el #{appointment.customer_starts_at_label}." },
          { tone: "Corta", text: "Hola #{appointment.customer_name}. Te recordamos tu turno en #{business.name}: #{appointment.customer_starts_at_label}." }
        ]
      end
  end
end
