module Ai
  class ConversationSummary
    def initialize(conversation:)
      @conversation = conversation
      @business = conversation.business
    end

    def call
      payload = GeminiClient.chat_json(
        system: system_prompt,
        messages: [ { role: "user", content: transcript } ],
        temperature: 0.35,
        max_tokens: 800,
        feature: "chat_followup_summary",
        business: business
      )

      summary = payload["summary"].to_s.strip.presence || fallback_summary
      suggested_text = payload["whatsapp_text"].to_s.strip.presence || default_whatsapp_text(summary)
      phone = conversation.detected_customer_phone

      conversation.update!(
        status: "summarized",
        summary_status: "completed",
        summary: summary,
        summarized_at: Time.current,
        customer_phone: phone,
        metadata: conversation.metadata.merge("suggested_whatsapp_text" => suggested_text)
      )

      create_event!(summary, suggested_text, phone)
      conversation
    rescue StandardError => error
      conversation.update!(summary_status: "failed", metadata: conversation.metadata.merge("summary_error" => error.message))
      raise
    end

    private
      attr_reader :conversation, :business

      def system_prompt
        <<~PROMPT
          Sos una secretaria comercial para #{business.name}. Resumí conversaciones de chat que quedaron sin reserva.
          Tu objetivo es que una persona del negocio pueda cerrar la venta por WhatsApp manual en un clic.
          Respondé exclusivamente JSON válido:
          {
            "summary": "un párrafo concreto con nombre/interés/dudas/horarios si aparecen",
            "whatsapp_text": "mensaje breve listo para enviar por WhatsApp"
          }
        PROMPT
      end

      def transcript
        conversation.ai_chat_messages.order(:created_at).map do |message|
          "#{message.role}: #{message.content}"
        end.join("\n").truncate(8_000)
      end

      def fallback_summary
        "El cliente conversó con el asistente, pero no llegó a reservar. Revisar la conversación para seguimiento manual."
      end

      def default_whatsapp_text(summary)
        "Hola, te escribimos de #{business.name}. Vimos tu consulta en la web y queríamos ayudarte a reservar. #{summary}"
      end

      def create_event!(summary, suggested_text, phone)
        business.provider_events.create!(
          event_type: "ai_chat_followup",
          title: "Chat pendiente para cerrar por WhatsApp",
          body: phone.present? ? summary : "#{summary} No se detectó WhatsApp en la conversación.",
          metadata: {
            conversation_id: conversation.id,
            customer_phone: phone,
            whatsapp_url: phone.present? ? PhoneNumber.whatsapp_link(phone, text: suggested_text) : nil
          }
        )
      end
  end
end
