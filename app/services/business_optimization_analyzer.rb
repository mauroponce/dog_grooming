class BusinessOptimizationAnalyzer
  HISTORY_DAYS = 30
  PROJECTION_DAYS = 7
  INACTIVE_DAYS = 45
  GEMINI_MODEL = "gemini-1.5-flash"

  def initialize(business:)
    @business = business
    @history_start = (HISTORY_DAYS - 1).days.ago.to_date
    @history_end = Time.zone.today
    @projection_start = Time.zone.today
    @projection_end = (PROJECTION_DAYS - 1).days.from_now.to_date
  end

  def call
    metrics = build_metrics
    {
      metrics: metrics,
      ai: ai_analysis(metrics)
    }
  end

  private
    attr_reader :business, :history_start, :history_end, :projection_start, :projection_end

    def build_metrics
      {
        generated_at: Time.current.iso8601,
        business: business_payload,
        assumptions: assumptions,
        history_window: window_payload(history_start, history_end),
        projection_window: window_payload(projection_start, projection_end),
        occupation: occupation_metrics,
        cancellations: cancellation_metrics,
        opportunity_cost: opportunity_cost_metrics,
        top_services_by_revenue: top_services_by_revenue,
        top_services_by_free_gaps: top_services_by_free_gaps,
        inactive_customers: inactive_customers,
        current_preferences: preferences_payload
      }
    end

    def business_payload
      {
        id: business.id,
        name: business.name,
        kind: business.business_kind_label,
        industry: business.industry_label,
        staff_agendas_count: staff_count
      }
    end

    def assumptions
      {
        no_show_definition: "Estimación: turnos pasados que quedaron pendientes o pendientes de pago/confirmación, porque todavía no existe un estado explícito de asistencia.",
        opportunity_cost_definition: "Minutos operativos vacíos multiplicados por el precio promedio por minuto de los servicios activos con precio.",
        staff_capacity_definition: "Horas operativas del negocio multiplicadas por cantidad actual de profesionales activas."
      }
    end

    def occupation_metrics
      available = historical_available_minutes
      booked = historical_booked_minutes
      projected_available = projected_available_minutes
      projected_booked = projected_booked_minutes

      {
        historical_available_hours: hours(available),
        historical_booked_hours: hours(booked),
        historical_empty_hours: hours([ available - booked, 0 ].max),
        historical_occupancy_rate: percentage(booked, available),
        projected_available_hours_next_7_days: hours(projected_available),
        projected_booked_hours_next_7_days: hours(projected_booked),
        projected_empty_hours_next_7_days: hours([ projected_available - projected_booked, 0 ].max),
        projected_occupancy_rate_next_7_days: percentage(projected_booked, projected_available)
      }
    end

    def cancellation_metrics
      total = historical_appointments.count
      canceled = historical_appointments.count(&:canceled?)
      late = historical_appointments.count(&:canceled_late?)
      no_show = no_show_appointments.count

      {
        total_appointments: total,
        canceled_count: canceled,
        cancellation_rate: percentage(canceled, total),
        late_cancellation_count: late,
        late_cancellation_rate: percentage(late, total),
        no_show_estimated_count: no_show,
        no_show_estimated_rate: percentage(no_show, total)
      }
    end

    def opportunity_cost_metrics
      available = historical_available_minutes
      booked = historical_booked_minutes
      empty_minutes = [ available - booked, 0 ].max
      lost_cents = (empty_minutes * average_revenue_per_minute_cents).round

      {
        empty_minutes: empty_minutes,
        empty_hours: hours(empty_minutes),
        average_revenue_per_minute_cents: average_revenue_per_minute_cents.round(2),
        lost_revenue_cents: lost_cents,
        lost_revenue_label: money(lost_cents)
      }
    end

    def top_services_by_revenue
      service_rows.map do |row|
        {
          service_id: row.fetch(:service).id,
          name: row.fetch(:service).name,
          revenue_cents: row.fetch(:revenue_cents),
          revenue_label: money(row.fetch(:revenue_cents)),
          appointments_count: row.fetch(:appointments_count),
          cancellation_rate: row.fetch(:cancellation_rate)
        }
      end.sort_by { |row| -row.fetch(:revenue_cents) }.first(3)
    end

    def top_services_by_free_gaps
      service_rows.map do |row|
        service = row.fetch(:service)
        possible_slots = possible_slots_for(service, history_start, history_end)
        booked_count = historical_appointments.count { |appointment| !appointment.canceled? && appointment.service_id == service.id }
        free_slots = [ possible_slots - booked_count, 0 ].max
        {
          service_id: service.id,
          name: service.name,
          possible_slots: possible_slots,
          booked_slots: booked_count,
          free_slots: free_slots,
          free_gap_rate: percentage(free_slots, possible_slots),
          estimated_gap_value_cents: free_slots * service.price_cents.to_i,
          estimated_gap_value_label: money(free_slots * service.price_cents.to_i)
        }
      end.select { |row| row.fetch(:possible_slots).positive? }
        .sort_by { |row| [ -row.fetch(:free_gap_rate), -row.fetch(:estimated_gap_value_cents) ] }
        .first(3)
    end

    def inactive_customers
      cutoff = INACTIVE_DAYS.days.ago
      grouped = business.appointments
        .active
        .includes(:service, :customer_profile)
        .where("starts_at < ?", cutoff)
        .group_by { |appointment| appointment.customer_profile || appointment.customer_phone }

      grouped.filter_map do |customer, appointments|
        next if appointments.size < 2

        last_appointment = appointments.max_by(&:starts_at)
        next if business.appointments.active.where(customer_phone: last_appointment.customer_phone).where("starts_at >= ?", cutoff).exists?

        recurring_service = appointments.group_by(&:service_id).max_by { |_service_id, grouped_appointments| grouped_appointments.size }&.last&.first&.service
        next unless recurring_service

        {
          customer_name: customer.respond_to?(:name) ? customer.name.presence || last_appointment.customer_name : last_appointment.customer_name,
          customer_phone: customer.respond_to?(:phone) ? customer.phone : last_appointment.customer_phone,
          last_appointment_at: last_appointment.starts_at.iso8601,
          last_appointment_label: CustomerDateFormatter.date_label(last_appointment.starts_at),
          recurrent_service_name: recurring_service.name,
          total_historical_appointments: appointments.size,
          estimated_reactivation_value_cents: recurring_service.price_cents.to_i,
          estimated_reactivation_value_label: money(recurring_service.price_cents.to_i)
        }
      end.sort_by { |row| [ -row.fetch(:total_historical_appointments), row.fetch(:last_appointment_at) ] }.first(8)
    end

    def preferences_payload
      {
        chatbot_enabled: business.chatbot_enabled?,
        deposits_enabled: business.deposits_enabled?,
        deposit_percentage: business.deposit_percentage
      }
    end

    def ai_analysis(metrics)
      return fallback_ai("Gemini no está configurado.") unless Ai::GeminiClient.available?

      payload = Ai::GeminiClient.chat_json(
        system: optimization_prompt,
        messages: [ { role: "user", content: JSON.pretty_generate(metrics) } ],
        temperature: 0.25,
        max_tokens: 1_800,
        model: ENV.fetch("GEMINI_OPTIMIZATION_MODEL", GEMINI_MODEL),
        feature: "business_optimization",
        business: business
      )

      normalize_ai_payload(payload)
    rescue StandardError => error
      Rails.logger.warn("Business optimization AI failed for business #{business.id}: #{error.class} #{error.message}")
      fallback_ai("No pude generar el plan con Gemini en este momento.")
    end

    def optimization_prompt
      <<~PROMPT
        Sos un Consultor Financiero y de Operaciones experto en negocios de #{business.industry_label}, agenda de turnos, ocupación, cancelaciones y recuperación de ingresos.
        Analizá exclusivamente el JSON provisto. No inventes datos que no estén en el payload.
        Si una métrica es estimada, mencioná que es una estimación y basá la recomendación en la definición indicada.

        Devolvé exclusivamente JSON válido con esta estructura:
        {
          "diagnosticos": [
            {
              "titulo": "título corto",
              "severidad": "Baja|Media|Alta",
              "metrica_clave": "dato numérico o financiero relevante",
              "descripcion": "diagnóstico basado en los datos"
            }
          ],
          "acciones_sugeridas": [
            {
              "titulo": "título corto y directo",
              "impacto_estimado": "$120.000",
              "dificultad": "Baja|Media|Alta",
              "justificacion": "explicación analítica basada en los datos provistos",
              "estrategia_automatizada": "acción concreta dentro del sistema para mitigar el problema"
            }
          ]
        }

        Priorizá acciones operativas: seña configurable, lista de espera, reactivación de clientes, ajuste de horarios y descuentos por horarios muertos.
        No recomiendes acciones médicas, legales ni promesas de resultados.
      PROMPT
    end

    def normalize_ai_payload(payload)
      diagnostics = Array(payload["diagnosticos"]).map do |entry|
        {
          "titulo" => entry["titulo"].to_s.presence || "Diagnóstico operativo",
          "severidad" => severity(entry["severidad"]),
          "metrica_clave" => entry["metrica_clave"].to_s,
          "descripcion" => entry["descripcion"].to_s
        }
      end
      actions = Array(payload["acciones_sugeridas"]).map do |entry|
        {
          "titulo" => entry["titulo"].to_s.presence || "Acción sugerida",
          "impacto_estimado" => entry["impacto_estimado"].to_s.presence || "$0",
          "dificultad" => difficulty(entry["dificultad"]),
          "justificacion" => entry["justificacion"].to_s,
          "estrategia_automatizada" => entry["estrategia_automatizada"].to_s
        }
      end

      {
        "status" => "ok",
        "diagnosticos" => diagnostics,
        "acciones_sugeridas" => actions
      }
    end

    def fallback_ai(message)
      {
        "status" => "unavailable",
        "message" => message,
        "diagnosticos" => [],
        "acciones_sugeridas" => []
      }
    end

    def severity(value)
      normalized_label(value).in?(%w[Baja Media Alta]) ? normalized_label(value) : "Media"
    end

    def difficulty(value)
      normalized_label(value).in?(%w[Baja Media Alta]) ? normalized_label(value) : "Media"
    end

    def normalized_label(value)
      value.to_s.strip.downcase.capitalize
    end

    def service_rows
      @service_rows ||= business.services.active.includes(:appointments).map do |service|
        appointments = historical_appointments.select { |appointment| appointment.service_id == service.id }
        active = appointments.reject(&:canceled?)
        {
          service: service,
          appointments_count: appointments.size,
          revenue_cents: active.sum { |appointment| appointment.final_price_cents.to_i.positive? ? appointment.final_price_cents.to_i : service.price_cents.to_i },
          cancellation_rate: percentage(appointments.count(&:canceled?), appointments.size)
        }
      end
    end

    def historical_appointments
      @historical_appointments ||= business.appointments.includes(:service, :customer_profile).where(starts_at: history_time_range).to_a
    end

    def projected_appointments
      @projected_appointments ||= business.appointments.includes(:service).where(starts_at: projection_time_range).to_a
    end

    def no_show_appointments
      @no_show_appointments ||= historical_appointments.select do |appointment|
        appointment.no_show? || (appointment.starts_at.past? && !appointment.canceled? && !appointment.confirmed?)
      end
    end

    def historical_available_minutes
      @historical_available_minutes ||= available_minutes_between(history_start, history_end)
    end

    def projected_available_minutes
      @projected_available_minutes ||= available_minutes_between(projection_start, projection_end)
    end

    def historical_booked_minutes
      @historical_booked_minutes ||= appointment_minutes(historical_appointments.reject(&:canceled?))
    end

    def projected_booked_minutes
      @projected_booked_minutes ||= appointment_minutes(projected_appointments.reject(&:canceled?))
    end

    def appointment_minutes(appointments)
      appointments.sum { |appointment| ((appointment.ends_at - appointment.starts_at) / 60).round }
    end

    def available_minutes_between(start_date, end_date)
      (start_date..end_date).sum do |date|
        rule = availability_rules_by_weekday[date.wday]
        next 0 unless rule&.active?

        ((rule.end_time.seconds_since_midnight - rule.start_time.seconds_since_midnight) / 60).to_i * staff_count
      end
    end

    def possible_slots_for(service, start_date, end_date)
      return 0 unless service.duration_minutes.to_i.positive?

      (start_date..end_date).sum do |date|
        rule = availability_rules_by_weekday[date.wday]
        next 0 unless rule&.active?

        window_minutes = ((rule.end_time.seconds_since_midnight - rule.start_time.seconds_since_midnight) / 60).to_i
        (window_minutes / service.duration_minutes).floor * staff_count
      end
    end

    def staff_count
      @staff_count ||= [ business.employee_memberships.available_for_booking.count, 1 ].max
    end

    def average_revenue_per_minute_cents
      @average_revenue_per_minute_cents ||= begin
        priced_services = business.services.active.select { |service| service.price_cents.to_i.positive? && service.duration_minutes.to_i.positive? }
        return 0.0 if priced_services.blank?

        total_price = priced_services.sum(&:price_cents).to_f
        total_minutes = priced_services.sum(&:duration_minutes).to_f
        total_price / total_minutes
      end
    end

    def availability_rules_by_weekday
      @availability_rules_by_weekday ||= business.availability_rules.index_by(&:weekday)
    end

    def history_time_range
      history_start.beginning_of_day..history_end.end_of_day
    end

    def projection_time_range
      projection_start.beginning_of_day..projection_end.end_of_day
    end

    def window_payload(start_date, end_date)
      {
        start_date: start_date.iso8601,
        end_date: end_date.iso8601,
        days: (end_date - start_date).to_i + 1
      }
    end

    def hours(minutes)
      (minutes.to_f / 60).round(2)
    end

    def percentage(value, total)
      return 0 if total.to_i.zero?

      ((value.to_f / total) * 100).round(1)
    end

    def money(cents)
      "$#{ActiveSupport::NumberHelper.number_to_delimited((cents.to_i / 100.0).round, delimiter: ".")}"
    end
end
