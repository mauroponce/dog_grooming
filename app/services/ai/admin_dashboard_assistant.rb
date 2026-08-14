module Ai
  class AdminDashboardAssistant
    MAX_QUESTION_LENGTH = 700
    MAX_HISTORY_MESSAGES = 8
    SPANISH_WEEKDAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze

    def initialize(business:, question:, history: [])
      @business = business
      @question = question.to_s.squish.truncate(MAX_QUESTION_LENGTH, omission: "")
      @history = Array(history).last(MAX_HISTORY_MESSAGES)
      @now = Time.zone.now
      @today = Time.zone.today
    end

    def call
      raise ArgumentError, "Escribí una pregunta para el asistente." if question.blank?

      local_answer = fillable_gaps_answer
      return local_answer if local_answer.present?

      local_answer = today_attention_answer
      return local_answer if local_answer.present?

      local_answer = weekly_business_summary_answer
      return local_answer if local_answer.present?

      raise "GEMINI_API_KEY no configurada" unless GeminiClient.available?

      GeminiClient.chat_text(
        system: system_prompt,
        messages: messages,
        temperature: 0.25,
        max_tokens: 700,
        feature: "admin_dashboard_assistant",
        business: business
      ).presence || "No pude generar una respuesta con los datos actuales."
    end

    private
      attr_reader :business, :question, :history, :now, :today

      def fillable_gaps_answer
        return unless fillable_gaps_question?

        gaps = fillable_gaps_for_today.first(6)
        return "Hoy no encontré huecos disponibles para llenar." if gaps.blank?

        suggested = []
        lines = [ "Hoy encontré #{gaps.size} #{pluralize_es(gaps.size, "hueco", "huecos")} disponibles:" ]

        gaps.each do |gap|
          services = gap.service_suggestions.map(&:name).first(3).join(", ")
          professional = gap.employee_membership&.display_name || gap.employee_membership&.name
          time_range = "#{time_label(gap.starts_at)}-#{time_label(gap.ends_at)}"
          line = "- #{time_range}"
          line << " con #{professional}" if professional.present?
          line << ": #{services}."

          candidates = suggested_customers_for(gap)
          if candidates.any?
            candidate_labels = candidates.first(3).map do |candidate|
              name = candidate.customer.name.presence || candidate.customer.phone
              suggested << name
              "#{name} (#{candidate.reason.downcase})"
            end
            line << " Conviene escribirle a #{candidate_labels.join(", ")}."
          else
            line << " No encontré clientes compatibles para este horario."
          end

          lines << line
        end

        suggested.uniq!
        if suggested.any?
          lines << ""
          lines << "Recomendación: empezá por #{suggested.first(5).join(", ")}."
        end
        lines.join("\n")
      rescue StandardError => error
        Rails.logger.warn("Admin assistant fillable gaps answer failed for business #{business.id}: #{error.class} #{error.message}")
        nil
      end

      def fillable_gaps_question?
        normalized = I18n.transliterate(question.to_s).downcase.gsub(/[¿?]/, " ").squish
        normalized.match?(/\b(hueco|huecos|espacio|espacios)\b/) && normalized.match?(/\b(llenar|lleno|escribir|contactar|conviene|cliente|clientes)\b/)
      end

      def today_attention_answer
        return unless today_attention_question?

        pending_reviews = business.appointments.awaiting_deposit_review.where(starts_at: now..7.days.from_now).order(:starts_at)
        pending_customer_actions = business.appointments.awaiting_customer_action.where(starts_at: now..7.days.from_now).order(:starts_at)
        remaining_today = business.appointments.active.includes(:service, :employee_membership).where(starts_at: now..today.end_of_day).order(:starts_at)
        gaps = fillable_gaps_for_today.first(3)

        lines = [ "Para hoy, priorizá esto:" ]

        if pending_reviews.any?
          lines << "• Revisá #{pending_reviews.count} #{pluralize_es(pending_reviews.count, "comprobante pendiente", "comprobantes pendientes")} para confirmar o liberar esos horarios."
        end

        if pending_customer_actions.any?
          sample = pending_customer_actions.first
          sample_customer = sample.customer_name.presence || "el cliente"
          lines << "• Contactá #{pending_customer_actions.count == 1 ? "a #{sample_customer}" : "a #{pending_customer_actions.count} clientes"} con seña o confirmación pendiente."
        end

        if gaps.any?
          gap_labels = gaps.map { |gap| gap_attention_label(gap) }
          lines << "• Tenés #{gaps.size} #{pluralize_es(gaps.size, "hueco", "huecos")} para intentar llenar hoy: #{gap_labels.join("; ")}."
        end

        if remaining_today.any?
          next_appointment = remaining_today.first
          lines << "• Próximo turno: #{next_appointment.customer_name} a las #{time_label(next_appointment.starts_at)} por #{next_appointment.service&.name || "servicio sin nombre"}."
        end

        if lines.size == 1
          lines << "• No veo pendientes críticos ni huecos accionables con los datos actuales."
          lines << "• Mantené la agenda al día y revisá si entran comprobantes o cancelaciones."
        end

        lines.join("\n")
      rescue StandardError => error
        Rails.logger.warn("Admin assistant attention answer failed for business #{business.id}: #{error.class} #{error.message}")
        nil
      end

      def today_attention_question?
        normalized = I18n.transliterate(question.to_s).downcase.gsub(/[¿?]/, " ").squish
        normalized.match?(/\b(atencion|atender|prioridad|prioridades|primero)\b/) ||
          normalized.match?(/\b(que hago|hacer hoy|necesita|pendiente|pendientes)\b/)
      end

      def gap_attention_label(gap)
        services = gap.service_suggestions.map(&:name).first(2).join(", ")
        label = "#{time_label(gap.starts_at)}-#{time_label(gap.ends_at)}"
        services.present? ? "#{label} (#{services})" : label
      end

      def fillable_gaps_for_today
        @fillable_gaps_for_today ||= Availability::FillableGaps.new(business: business, date: today).call
      end

      def suggested_customers_for(gap)
        Gaps::SuggestedCustomers.new(business: business, gap: gap, limit: 8).call
      end

      def time_label(value)
        value&.in_time_zone&.strftime("%H:%M")
      end

      def weekly_business_summary_answer
        return unless weekly_business_summary_question?

        appointments = business.appointments
          .includes(:service, :employee_membership)
          .where(starts_at: weekly_summary_range)
          .order(:starts_at)
        active_appointments = appointments.where.not(status: Appointment.statuses.values_at(*Appointment::TERMINAL_STATUSES))
        confirmed_appointments = active_appointments.where(status: Appointment.statuses[:confirmed])
        pending_payment_appointments = active_appointments.where(status: Appointment.statuses.values_at("pending_payment", "pending_deposit", "deposit_rejected"))
        pending_review_appointments = active_appointments.where(status: Appointment.statuses[:pending_deposit_review])

        lines = [
          "Resumen:",
          "• #{confirmed_appointments.count} #{pluralize_es(confirmed_appointments.count, "turno confirmado", "turnos confirmados")} por #{format_money(confirmed_appointments.sum(:final_price_cents))}.",
          "• #{pending_payment_appointments.count} #{pluralize_es(pending_payment_appointments.count, "turno pendiente de seña", "turnos pendientes de seña")}, con #{format_money(pending_payment_appointments.sum(:deposit_amount_cents))} por cobrar.",
          "• #{pending_review_appointments.count} #{pluralize_es(pending_review_appointments.count, "comprobante para revisar", "comprobantes para revisar")}."
        ]

        upcoming_confirmed = confirmed_appointments.first
        if upcoming_confirmed.present?
          lines << ""
          lines << "Próximo turno confirmado:"
          lines << "• #{upcoming_confirmed.customer_name} — #{weekly_appointment_date_label(upcoming_confirmed.starts_at)} con #{upcoming_confirmed.employee_membership&.name || "sin profesional asignado"}."
          lines << "  Servicio: #{upcoming_confirmed.service&.name || "Servicio sin nombre"}."
        end

        lines << ""
        lines << "Lo más importante ahora:"
        lines << weekly_priority(pending_payment_appointments, pending_review_appointments, confirmed_appointments)
        lines << ""
        lines << "Acciones sugeridas:"
        lines << "• Enviar WhatsApp a clientes con seña pendiente."
        lines << "• Ver turnos pendientes."
        lines << "• Revisar huecos libres de la semana."
        lines.join("\n")
      end

      def weekly_business_summary_question?
        normalized = I18n.transliterate(question.to_s).downcase.gsub(/[¿?]/, "").squish
        normalized.include?("como viene") && normalized.include?("negocio") && normalized.include?("semana")
      end

      def weekly_summary_range
        now.beginning_of_day..7.days.from_now.end_of_day
      end

      def weekly_appointment_date_label(value)
        local_time = value.in_time_zone
        "#{SPANISH_WEEKDAYS.fetch(local_time.wday)} #{local_time.strftime("%d/%m")} a las #{local_time.strftime("%H:%M")}"
      end

      def weekly_priority(pending_payment_appointments, pending_review_appointments, confirmed_appointments)
        if pending_review_appointments.any?
          "Revisá los #{pending_review_appointments.count} #{pluralize_es(pending_review_appointments.count, "comprobante pendiente", "comprobantes pendientes")} para confirmar esas reservas y no bloquear horarios innecesariamente."
        elsif pending_payment_appointments.any?
          count = pending_payment_appointments.count
          contact_target = count == 1 ? "al cliente con seña pendiente para que confirme el turno" : "a los #{count} clientes con seña pendiente para que confirmen los turnos"
          "Contactá #{contact_target}. Si no pagan la seña, esos horarios siguen en riesgo."
        elsif confirmed_appointments.any?
          "Usá los #{confirmed_appointments.count} #{pluralize_es(confirmed_appointments.count, "turno confirmado", "turnos confirmados")} como base de agenda y revisá los huecos libres para sumar reservas esta semana."
        else
          "No hay turnos confirmados esta semana. Priorizá los huecos disponibles y el contacto con clientes frecuentes."
        end
      end

      def format_money(cents)
        value = cents.to_i
        return "$0" if value.zero?

        "$#{(value / 100).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
      end

      def pluralize_es(count, singular, plural)
        count.to_i == 1 ? singular : plural
      end

      def messages
        safe_history + [
          {
            role: "user",
            content: <<~PROMPT
              Contexto consultado desde la base de datos para este negocio:
              #{Admin::AssistantContextBuilder.new(business: business).to_prompt}

              Pregunta del admin:
              #{question}
            PROMPT
          }
        ]
      end

      def safe_history
        history.filter_map do |message|
          role = message.respond_to?(:[]) ? message[:role] || message["role"] : nil
          content = message.respond_to?(:[]) ? message[:content] || message["content"] : nil
          next if content.blank?

          {
            role: role.to_s == "assistant" ? "assistant" : "user",
            content: content.to_s.squish.truncate(900, omission: "")
          }
        end
      end

      def system_prompt
        <<~PROMPT
          Sos el Asistente Dog Grooming para administradoras de peluquerías caninas en Argentina.
          Respondé en español rioplatense, con tono claro, concreto y accionable.

          Reglas de seguridad y alcance:
          - Usá únicamente el contexto JSON provisto por Rails para el negocio actual.
          - No inventes datos, clientes, servicios, importes ni horarios.
          - Si el contexto no alcanza, decí exactamente qué dato falta.
          - Nunca afirmes que consultaste otros negocios ni mezcles información entre negocios.
          - No menciones IDs internos, tokens, implementación, SQL ni nombres de tablas.
          - Podés sugerir próximos pasos, pero no confirmes turnos ni modifiques datos.
          - Si hay importes, mostralos con formato argentino.
          - Priorizá respuestas breves: 1 a 4 bullets o un párrafo corto.
          - Para preguntas frecuentes, estructurá la respuesta como: respuesta directa, contexto relevante, recomendación concreta y acción sugerida.
          - Si la pregunta trata sobre huecos o espacios libres, usá los datos de fillable_gaps_today. No respondas con un resumen de turnos agendados: informá horarios libres, servicios compatibles y clientes sugeridos para contactar.
          - Priorizá lo que requiere atención hoy, huecos que se pueden llenar, clientes para contactar, comprobantes pendientes, riesgos de ausencia y oportunidades de ingresos.
          - No listes métricas aisladas si no ayudan a decidir una acción.
        PROMPT
      end
  end
end
