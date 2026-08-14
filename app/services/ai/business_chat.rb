module Ai
  class BusinessChat
    def initialize(business:)
      @business = business
    end

    def call(conversation:)
      raise "Chat IA no disponible para este negocio" unless business.ai_chat_available?

      tool_results = execute_tool_calls(conversation)
      return tool_response(tool_results) if tool_results.any?

      payload = GeminiClient.chat_json(
        system: system_prompt,
        messages: messages_for(conversation),
        temperature: 0.2,
        max_tokens: 700,
        feature: "public_chat",
        business: business
      )

      {
        answer: payload["answer"].presence || "No pude responder en este momento.",
        intent: normalize_intent(payload["intent"]),
        recommended_service_ids: normalize_service_ids(payload["recommended_service_ids"]),
        components: [],
        tool_results: []
      }
    end

    private
      attr_reader :business

      def execute_tool_calls(conversation)
        toolbox = ChatTools.new(business: business)
        calls = GeminiClient.function_calls(
          system: system_prompt,
          messages: messages_for(conversation),
          tools: toolbox.declarations,
          temperature: 0.0,
          feature: "public_chat_tools",
          business: business
        )
        tool_results = calls.first(2).map { |call| toolbox.call(call.fetch(:name), call.fetch(:arguments)) }
        consolidate_availability_results(toolbox, tool_results)
      end

      def tool_response(tool_results)
        components = tool_results.filter_map { |result| result[:component] || result["component"] }
        answers = tool_results.map { |result| result[:answer] || result["answer"] }.compact_blank.uniq
        {
          answer: answers.join("\n").presence || "Listo.",
          intent: intent_for_tools(tool_results),
          recommended_service_ids: service_ids_for_tools(tool_results),
          components: components,
          tool_results: tool_results
        }
      end

      def consolidate_availability_results(toolbox, tool_results)
        unavailable_checks = tool_results.select { |result| unavailable_availability_check?(result) }
        return tool_results if unavailable_checks.blank?

        available_checks = tool_results.select { |result| available_availability_check?(result) }
        return tool_results - unavailable_checks if available_checks.any?
        return tool_results if tool_results.any? { |result| (result[:tool] || result["tool"]) == "find_available_slots" }

        first_check = unavailable_checks.first
        component = first_check[:component] || first_check["component"] || {}
        service = component[:service] || component["service"] || {}
        service_id = service[:id] || service["id"]
        starts_at = Time.zone.parse((component[:starts_at] || component["starts_at"]).to_s)
        return tool_results if service_id.blank? || starts_at.blank?

        alternatives = toolbox.call(
          "find_available_slots",
          service_id: service_id,
          start_date: starts_at.to_date.iso8601,
          end_date: (starts_at.to_date + 14).iso8601,
          period: period_for_time(starts_at),
          limit: 3
        )

        slots = alternatives.dig(:component, :slots) || alternatives.dig("component", "slots") || []
        return [ first_check ] if slots.blank?

        alternatives[:answer] = "Ese horario no está disponible, pero encontré estas alternativas disponibles."
        (tool_results - unavailable_checks) + [ alternatives ]
      rescue ArgumentError, TypeError
        tool_results
      end

      def unavailable_availability_check?(result)
        component = result[:component] || result["component"] || {}
        (result[:tool] || result["tool"]) == "check_availability" &&
          (component[:type] || component["type"]) == "availability_result" &&
          !(component[:available] || component["available"])
      end

      def available_availability_check?(result)
        component = result[:component] || result["component"] || {}
        (result[:tool] || result["tool"]) == "check_availability" &&
          (component[:type] || component["type"]) == "availability_result" &&
          (component[:available] || component["available"])
      end

      def period_for_time(value)
        hour = value.in_time_zone.hour
        return "morning" if hour < 12
        return "afternoon" if hour < 18

        "evening"
      end

      def system_prompt
        <<~PROMPT
          Sos un asistente de gestión de turnos automatizado de #{business.name}. Respondé en español rioplatense.
          Adaptá el tono y el nivel de formalidad al rubro del negocio actual.
          Hoy es #{Time.zone.today.iso8601}. Usá esta fecha para interpretar pedidos relativos.

          Sos un asistente de gestión de turnos automatizado. Tenés prohibido responder preguntas que no estén directamente relacionadas con los servicios, horarios o turnos del comercio.
          Para cualquier dato variable (precios, horarios libres, turnos existentes), estás obligado a invocar la herramienta correspondiente. Nunca inventes una respuesta ni asumas disponibilidad.

          Podés responder consultas sobre servicios, horarios, ubicación, políticas, precios y preparación previa usando solo el contexto del negocio.
          No inventes información que no esté en el contexto. Si falta un dato, decí que conviene consultarlo directamente con el negocio.
          No canceles, reprogrames ni confirmes turnos desde el chat. No crees reservas salvo mediante la herramienta generate_booking_or_deposit_link y solo cuando el cliente ya dio servicio, fecha/hora, nombre y telefono.
          Para crear una solicitud de reserva o un link de carga de comprobante, invocá generate_booking_or_deposit_link solo si tenés servicio, fecha/hora, nombre y telefono.
          Para listar servicios, precios o duraciones, invocá get_services_catalog.
          Para consultar disponibilidad con fecha y hora exactas, invocá check_availability.
          Para pedidos flexibles de reserva o disponibilidad, invocá find_available_slots. Ejemplos: "cualquier dia por la mañana", "a mediados de julio", "esta semana", "la semana que viene", "mañana a la tarde", "cuando tengas lugar".
          Usá check_availability solo si la persona dio un día exacto y una hora exacta. Si dio una fecha aproximada, rango o franja horaria, usá find_available_slots.
          Nunca muestres como opción un horario no disponible. Ofrecé solo horarios devueltos como disponibles por las herramientas.
          Si la persona dice "mediados de julio", interpretalo como un rango cercano al 10-20 de julio del año vigente o del próximo año si esa ventana ya pasó.
          Para buscar o cancelar un turno existente, invocá find_appointment_by_contact si la persona informó email o telefono. Si no informó contacto, pedilo.

          Detectá intención de reserva cuando la persona diga frases como "quiero reservar", "tenés turno", "me quiero hacer", "necesito turno", "hay lugar hoy" o mencione un servicio con intención de compra.

          Respondé exclusivamente JSON válido con esta forma:
          {
            "answer": "respuesta visible para el cliente",
            "intent": "booking_shortcut" o "none",
            "recommended_service_ids": [ids numericos de servicios relevantes]
          }

          Usá recommended_service_ids solo con IDs reales de esta lista:
          #{services_context}

          Datos básicos:
          Nombre: #{business.name}
          #{business.ai_industry_context}
          Ubicación: #{business.public_location}
          Horarios: #{business.weekly_hours_summary}
          Política de cancelación: #{business.cancellation_policy_text}

          Contexto del negocio:
          #{business.ai_context}
        PROMPT
      end

      def messages_for(conversation)
        conversation.ai_chat_messages.order(:created_at).last(10).map do |message|
          {
            role: message.assistant? ? "model" : "user",
            content: message.content.to_s.truncate(1_500)
          }
        end
      end

      def services_context
        business.services.publicly_bookable.order(:name).map do |service|
          "- ID #{service.id}: #{service.name} (#{service.category_label}, #{service.duration_minutes} min, #{service.display_price})"
        end.join("\n")
      end

      def normalize_intent(value)
        value == "booking_shortcut" ? "booking_shortcut" : "none"
      end

      def normalize_service_ids(values)
        ids = Array(values).filter_map { |id| Integer(id, exception: false) }
        allowed_ids = business.services.publicly_bookable.where(id: ids).pluck(:id)
        ids & allowed_ids
      end

      def intent_for_tools(tool_results)
        names = tool_results.map { |result| result[:tool] || result["tool"] }
        return "booking_shortcut" if names.any? { |name| name.in?(%w[get_services_catalog check_availability find_available_slots generate_booking_or_deposit_link]) }

        "none"
      end

      def service_ids_for_tools(tool_results)
        ids = tool_results.flat_map do |result|
          component = result[:component] || result["component"] || {}
          services = component[:services] || component["services"] || []
          service = component[:service] || component["service"]
          appointment_service_id = component.dig(:appointment, :service_id) || component.dig("appointment", "service_id")
          Array(services).map { |entry| entry[:id] || entry["id"] } + [ service&.fetch(:id, nil) || service&.fetch("id", nil), appointment_service_id ]
        end
        normalize_service_ids(ids.compact)
      end
  end
end
