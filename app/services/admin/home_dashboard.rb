module Admin
  class HomeDashboard
    Metric = Struct.new(:label, :value, :hint, :tone, keyword_init: true)
    Priority = Struct.new(:title, :body, :tone, :icon, :path, :action_label, keyword_init: true)
    OpportunityService = Struct.new(:id, :key, :name, :duration_label, :price_label, :price_cents, keyword_init: true)
    OpportunityCandidate = Struct.new(
      :id,
      :name,
      :initials,
      :phone_label,
      :service_id,
      :service_key,
      :service_name,
      :reason,
      :reasons,
      :compatibility_label,
      :compatibility_tone,
      :last_visit_label,
      :source,
      keyword_init: true
    )
    Opportunity = Struct.new(
      :key,
      :starts_at,
      :ends_at,
      :time_label,
      :duration_minutes,
      :duration_label,
      :employee_membership,
      :employee_name,
      :employee_initials,
      :employee_color,
      :service_suggestions,
      :candidates,
      :waitlist_count,
      :badge_label,
      :tone,
      :potential_label,
      :potential_min_cents,
      :potential_max_cents,
      :candidate_summary,
      keyword_init: true
    ) do
      def candidates_count
        candidates.size
      end

      def services_count
        service_suggestions.size
      end

      def high_candidates_count
        candidates.count { |candidate| candidate.compatibility_tone == "high" || candidate.compatibility_tone == "waitlist" }
      end

      def has_candidates?
        candidates_count.positive?
      end
    end

    attr_reader :business, :appointments_scope, :current_user, :date

    def initialize(business:, appointments_scope:, current_user:, date: Time.zone.today)
      @business = business
      @appointments_scope = appointments_scope.where(business_id: business.id)
      @current_user = current_user
      @date = date.to_date
    end

    def greeting_name
      employee_name.presence || current_user.name.presence || current_user.email_address.to_s.split("@").first.presence || "Admin"
    end

    def status_label
      if business.services.publicly_bookable.exists? && business.availability_rules.where(active: true).exists?
        "Todo funcionando"
      else
        "Configuración pendiente"
      end
    end

    def today_appointments_count
      active_today_appointments.size
    end

    def confirmed_today_count
      active_today_appointments.count { |appointment| appointment.confirmed? || appointment.pending_confirmation? }
    end

    def confirmed_percentage_label
      return "0% del día" if today_appointments_count.zero?

      "#{((confirmed_today_count.to_f / today_appointments_count) * 100).round}% del día"
    end

    def estimated_revenue_cents
      @estimated_revenue_cents ||= active_today_appointments.sum { |appointment| appointment_price_cents(appointment) }
    end

    def revenue_delta_label
      previous = comparable_revenue_cents
      return "Sin comparación semanal" if previous.zero? && estimated_revenue_cents.zero?
      return "Nuevo movimiento vs. semana pasada" if previous.zero?

      delta = (((estimated_revenue_cents - previous).to_f / previous) * 100).round
      "#{delta.positive? ? '+' : ''}#{delta}% vs. #{day_name(date - 7).downcase} pasado"
    end

    def occupancy_percent
      return 0 if available_minutes.zero?

      [ ((booked_minutes.to_f / available_minutes) * 100).round, 100 ].min
    end

    def occupancy_label
      "#{occupancy_percent}%"
    end

    def next_appointment
      upcoming_appointments.first
    end

    def next_appointment_title
      return "Sin próximos turnos" unless next_appointment

      "#{time_label(next_appointment.starts_at)} · #{next_appointment.service.name}"
    end

    def next_appointment_hint
      return "Agenda libre por ahora" unless next_appointment

      [ next_appointment.customer_name, next_appointment.employee_membership&.display_name ].compact_blank.join(" con ")
    end

    def pending_proofs_count
      @pending_proofs_count ||= appointments_scope.awaiting_deposit_review.where("starts_at >= ?", date.beginning_of_day).count
    end

    def pending_proofs_today_count
      @pending_proofs_today_count ||= appointments_scope.awaiting_deposit_review.where(starts_at: day_range).count
    end

    def pending_customer_action_count
      @pending_customer_action_count ||= appointments_scope.awaiting_customer_action.where(starts_at: day_range).count
    end

    def returning_customers_count
      @returning_customers_count ||= begin
        last_visits = business.appointments
          .where.not(customer_profile_id: nil)
          .where(status: Appointment.statuses.values_at("confirmed", "completed"))
          .where("starts_at < ?", Time.current)
          .group(:customer_profile_id)
          .maximum(:starts_at)
        return 0 if last_visits.blank?

        future_customer_ids = business.appointments.active.where("starts_at >= ?", Time.current).where.not(customer_profile_id: nil).distinct.pluck(:customer_profile_id)
        cutoff = 25.days.ago
        last_visits.count { |customer_id, last_visit| last_visit <= cutoff && !future_customer_ids.include?(customer_id) }
      end
    end

    def first_fillable_gap
      fillable_gaps.first
    end

    def first_offerable_gap
      ranked_offerable_gaps.first
    end

    def fillable_gap_minutes
      fillable_gaps.sum(&:duration_minutes)
    end

    def short_notice_gaps?
      minimum_duration_gaps.any? && offerable_gaps.blank?
    end

    def too_short_gaps?
      fillable_gaps.any? && minimum_duration_gaps.blank?
    end

    def opportunities
      @opportunities ||= ranked_offerable_gaps
        .first(maximum_visible_opportunities)
        .each_with_index
        .map { |gap, index| build_opportunity(gap, index) }
    end

    def opportunities_count
      opportunities.size
    end

    def opportunity_minutes
      opportunities.sum(&:duration_minutes)
    end

    def opportunity_candidates_count
      opportunity_candidates.size
    end

    def high_opportunity_candidates_count
      opportunity_candidates.count { |candidate| candidate.compatibility_tone == "high" || candidate.compatibility_tone == "waitlist" }
    end

    def opportunity_potential_cents
      opportunities.sum { |opportunity| opportunity.potential_max_cents.to_i }
    end

    def opportunity_summary_title
      return "La jornada de hoy terminó" if day_finished?
      return "Quedan huecos libres, pero ya no dan tiempo para ofrecerlos" if short_notice_gaps?
      return "Hay tiempo libre, pero no alcanza para otro servicio" if too_short_gaps?
      return "No hay huecos para ofrecer por ahora" if opportunities.blank? && fillable_gaps.blank?
      return "Hay huecos útiles, pero todavía estamos aprendiendo sobre tus clientes" if opportunities.any? && opportunity_candidates_count.zero?

      "Tenés #{opportunities_count} #{plural_label(opportunities_count, 'espacio', 'espacios')} que todavía podrías llenar."
    end

    def opportunity_summary_copy
      return "Hoy registraste #{today_activity_summary}." if day_finished?
      if short_notice_gaps?
        return "Quedan #{fillable_gap_minutes} minutos libres desde las #{time_label(first_fillable_gap.starts_at)}, pero la anticipación mínima para ofrecerlos es de #{minimum_offer_lead_minutes} min. Podés usar el calendario para cargar un turno manual."
      end
      if too_short_gaps?
        return "Los #{fillable_gap_minutes} minutos libres que quedan no alcanzan para un servicio de al menos #{minimum_opportunity_minutes} min. Revisá el calendario si querés acomodar la agenda manualmente."
      end
      if opportunities.blank? && fillable_gaps.blank?
        return "Hoy tenés #{today_activity_summary}. Revisá el calendario o la configuración de horarios para encontrar disponibilidad."
      end
      if opportunities.any? && opportunity_candidates_count.zero?
        return "Encontramos servicios que entran en esos horarios, pero aún no hay suficiente historial para sugerir clientes compatibles."
      end

      "Encontramos servicios compatibles y #{opportunity_candidates_count} #{plural_label(opportunity_candidates_count, 'cliente', 'clientes')} con motivos concretos para ofrecerles esos horarios."
    end

    def opportunity_state
      return :day_finished if day_finished?
      return :short_notice if short_notice_gaps?
      return :too_short if too_short_gaps?
      return :unavailable if opportunities.blank? && fillable_gaps.blank?
      return :no_candidates if opportunities.any? && opportunity_candidates_count.zero?

      :available
    end

    def opportunity_summary_kicker
      return "Resumen de hoy" if day_finished?
      return "Disponibilidad de hoy" if short_notice_gaps? || too_short_gaps?

      "Oportunidades para hoy"
    end

    def opportunity_section_title
      short_notice_gaps? || too_short_gaps? ? "Disponibilidad restante hoy" : "Oportunidades para hoy"
    end

    def opportunity_section_copy
      if short_notice_gaps?
        "Estos horarios siguen libres en la agenda, pero no se recomiendan para una campaña porque empiezan demasiado pronto."
      elsif too_short_gaps?
        "Estos espacios siguen libres en la agenda, pero son más cortos que el mínimo para ofrecer un servicio."
      else
        "Huecos disponibles que todavía podrías cubrir con clientes compatibles."
      end
    end

    def calendar_action_label
      short_notice_gaps? || too_short_gaps? ? "Abrir calendario" : "Ver todos los huecos"
    end

    def opportunity_summary_metrics
      return @opportunity_summary_metrics if defined?(@opportunity_summary_metrics)

      @opportunity_summary_metrics = if day_finished?
        [
          Metric.new(
            label: "Turnos de hoy",
            value: today_appointments_count,
            hint: "#{booked_minutes} min reservados",
            tone: "violet"
          ),
          Metric.new(
            label: "Señas pendientes",
            value: pending_deposit_today_count,
            hint: pending_deposit_today_count.positive? ? "#{money(pending_deposit_today_cents)} por cobrar" : "Sin señas pendientes",
            tone: "rose"
          ),
          Metric.new(
            label: "Facturación estimada del día",
            value: money(estimated_revenue_cents),
            hint: "Según los turnos registrados.",
            tone: "emerald"
          )
        ]
      elsif short_notice_gaps? || too_short_gaps?
        [
          Metric.new(
            label: too_short_gaps? ? "Huecos cortos" : "Huecos libres",
            value: fillable_gaps_count,
            hint: "#{fillable_gap_minutes} minutos disponibles",
            tone: "violet"
          ),
          Metric.new(
            label: "Clientes sugeridos",
            value: 0,
            hint: too_short_gaps? ? "No entra ningún servicio" : "Sin tiempo suficiente para ofrecer hoy",
            tone: "violet"
          ),
          Metric.new(
            label: too_short_gaps? ? "Mayor hueco" : "Próximo hueco",
            value: too_short_gaps? ? duration_label(fillable_gaps.map(&:duration_minutes).max) : time_label(first_fillable_gap.starts_at),
            hint: too_short_gaps? ? "Mínimo para ofrecer: #{minimum_opportunity_minutes} min" : duration_label(first_fillable_gap.duration_minutes),
            tone: "violet"
          )
        ]
      else
        [
          Metric.new(
            label: "Huecos útiles",
            value: opportunities_count,
            hint: "#{opportunity_minutes} minutos disponibles",
            tone: "violet"
          ),
          Metric.new(
            label: "Clientes sugeridos",
            value: opportunity_candidates_count,
            hint: "#{high_opportunity_candidates_count} con compatibilidad alta",
            tone: "violet"
          ),
          Metric.new(
            label: "Valor potencial de los espacios",
            value: money(opportunity_potential_cents),
            hint: "Estimado según los servicios que entran.",
            tone: "violet"
          )
        ]
      end
    end

    def opportunity_empty_title
      return "La jornada de hoy terminó" if opportunity_state == :day_finished
      return "Quedan huecos para un turno manual" if opportunity_state == :short_notice
      return "Los huecos libres son demasiado cortos" if opportunity_state == :too_short
      return "No hay huecos para ofrecer por ahora" if opportunity_state == :unavailable

      "Todavía estamos aprendiendo sobre tus clientes"
    end

    def opportunity_empty_copy
      return "Hoy registraste #{today_activity_summary}. Mañana vas a volver a ver los horarios disponibles." if opportunity_state == :day_finished
      return "Los espacios libres de hoy empiezan demasiado pronto para enviar ofertas. Abrí el calendario si querés asignarlos manualmente." if opportunity_state == :short_notice
      return "No entra ningún servicio en los espacios libres que quedan. Abrí el calendario si querés reorganizar la agenda manualmente." if opportunity_state == :too_short
      return "Hoy tenés #{today_activity_summary}. Revisá el calendario o la configuración de horarios para encontrar disponibilidad." if opportunity_state == :unavailable

      "Cuando completes algunas visitas, Cita.pet podrá recomendar a qué tutores ofrecer cada hueco."
    end

    def opportunity_payloads
      opportunities.map do |opportunity|
        {
          key: opportunity.key,
          title: "#{opportunity.time_label} · #{opportunity.employee_name}",
          subtitle: "#{opportunity.duration_label} disponibles#{opportunity.potential_label.present? ? " · #{opportunity.potential_label}" : ""}",
          startsAt: opportunity.starts_at.iso8601,
          endsAt: opportunity.ends_at.iso8601,
          employeeId: opportunity.employee_membership&.id,
          updatedAt: "Actualizado ahora",
          servicesCount: opportunity.services_count,
          candidatesCount: opportunity.candidates_count,
          services: opportunity.service_suggestions.map do |service|
            {
              id: service.id,
              key: service.key,
              name: service.name,
              durationLabel: service.duration_label,
              priceLabel: service.price_label
            }
          end,
          candidates: opportunity.candidates.map do |candidate|
            {
              id: candidate.id,
              name: candidate.name,
              initials: candidate.initials,
              phoneLabel: candidate.phone_label,
              serviceId: candidate.service_id,
              serviceKey: candidate.service_key,
              serviceName: candidate.service_name,
              reason: candidate.reason,
              reasons: candidate.reasons,
              compatibilityLabel: candidate.compatibility_label,
              compatibilityTone: candidate.compatibility_tone,
              lastVisitLabel: candidate.last_visit_label,
              source: candidate.source
            }
          end
        }
      end
    end

    def fillable_gaps_count
      fillable_gaps.size
    end

    def hero_title
      if today_appointments_count.positive?
        "Tenés #{today_appointments_count} #{plural_label(today_appointments_count, 'turno', 'turnos')} y #{occupancy_label} de ocupación."
      elsif business.availability_rules.where(active: true).exists?
        "Hoy tenés la agenda libre para recibir reservas."
      else
        "Completá tus horarios para empezar a recibir reservas."
      end
    end

    def hero_copy
      return "La jornada de hoy terminó. Revisá el resumen de tus turnos antes de preparar mañana" if day_finished?

      parts = []
      parts << "#{pending_proofs_count} #{plural_label(pending_proofs_count, 'comprobante', 'comprobantes')} para revisar" if pending_proofs_count.positive?
      parts << gap_sentence if first_offerable_gap.present?
      parts << short_notice_gap_sentence if short_notice_gaps?
      parts << "#{returning_customers_count} #{plural_label(returning_customers_count, 'cliente', 'clientes')} podrían volver" if returning_customers_count.positive?
      parts << "El resto está en orden" if parts.blank?
      parts.to_sentence(last_word_connector: " y ")
    end

    def hero_intro_copy
      return hero_copy if day_finished?
      return hero_copy if short_notice_gaps? || too_short_gaps?

      "Estos son los espacios que todavía podés convertir en reservas hoy. #{hero_copy}"
    end

    def metrics
      [
        Metric.new(label: "Confirmados", value: confirmed_today_count, hint: confirmed_percentage_label, tone: "emerald"),
        Metric.new(label: "Facturación estimada", value: money(estimated_revenue_cents), hint: revenue_delta_label, tone: "emerald"),
        Metric.new(label: "Ocupación del día", value: occupancy_label, hint: "#{booked_minutes} min reservados", tone: "violet")
      ]
    end

    def upcoming_appointments
      @upcoming_appointments ||= upcoming_appointments_scope.limit(10).to_a
    end

    def upcoming_appointments_scope
      appointments_scope.active
        .includes(:service, :employee_membership)
        .where("starts_at >= ?", Time.current)
        .order(starts_at: :asc, id: :asc)
    end

    def upcoming_appointment_day_label(appointment)
      appointment_date = appointment.starts_at.to_date
      return "Hoy" if appointment_date == Time.zone.today
      return "Mañana" if appointment_date == Time.zone.today + 1.day

      "#{day_name(appointment_date).capitalize} #{appointment.starts_at.strftime('%d/%m')}"
    end

    def priority_items
      items = []
      if pending_proofs_count.positive?
        items << Priority.new(
          title: "#{pending_proofs_count} #{plural_label(pending_proofs_count, 'comprobante', 'comprobantes')} pendientes",
          body: pending_proofs_today_count.positive? ? "#{pending_proofs_today_count} corresponden a turnos de hoy." : "Revisalos para liberar confirmaciones.",
          tone: "rose",
          icon: "receipt",
          path: Rails.application.routes.url_helpers.admin_calendar_path,
          action_label: "Revisar"
        )
      end

      if first_offerable_gap.present?
        gap = first_offerable_gap
        employee = gap.employee_membership&.display_name || "el equipo"
        items << Priority.new(
          title: "Hueco de #{gap.duration_minutes} minutos",
          body: "#{employee} tiene disponibilidad desde #{time_label(gap.starts_at)}. Entran #{gap.service_suggestions.map(&:name).first(2).to_sentence(last_word_connector: ' o ')}.",
          tone: "violet",
          icon: "calendar_search",
          path: Rails.application.routes.url_helpers.admin_calendar_path(date: gap.starts_at.to_date.iso8601),
          action_label: "Ver hueco"
        )
      end

      if pending_customer_action_count.positive?
        items << Priority.new(
          title: "#{pending_customer_action_count} #{plural_label(pending_customer_action_count, 'turno', 'turnos')} sin confirmar",
          body: "Conviene revisar estos turnos antes de que avance el día.",
          tone: "amber",
          icon: "bell",
          path: Rails.application.routes.url_helpers.admin_calendar_path(date: date.iso8601),
          action_label: "Ver turnos"
        )
      end

      if returning_customers_count.positive?
        items << Priority.new(
          title: "#{returning_customers_count} #{plural_label(returning_customers_count, 'cliente', 'clientes')} podrían volver",
          body: "Tuvieron una visita previa y no tienen turnos próximos.",
          tone: "emerald",
          icon: "users",
          path: Rails.application.routes.url_helpers.admin_customer_profiles_path,
          action_label: "Ver clientes"
        )
      end

      if items.blank?
        items << Priority.new(
          title: "No hay pendientes urgentes",
          body: "Podés aprovechar para revisar servicios, clientes o disponibilidad.",
          tone: "emerald",
          icon: "check",
          path: Rails.application.routes.url_helpers.admin_calendar_path,
          action_label: "Ver calendario"
        )
      end

      items.first(4)
    end

    def quick_stats
      {
        services: business.services_count.to_i,
        customers: business.customer_profiles.count,
        team: business.employee_memberships_count.to_i,
        pending_proofs: pending_proofs_count
      }
    end

    def appointment_duration_label(appointment)
      minutes = ((appointment.ends_at - appointment.starts_at) / 60).round
      return "#{minutes} min" if minutes < 60

      hours = minutes / 60
      remainder = minutes % 60
      remainder.zero? ? "#{hours} h" : "#{hours} h #{remainder} min"
    end

    def money(cents)
      value = cents.to_i
      return "$0" if value.zero?

      "$#{(value / 100).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
    end

    def time_label(value)
      value&.in_time_zone&.strftime("%H:%M")
    end

    private
      def employee_name
        membership = current_user&.employee_membership_for(business)
        membership&.display_name
      end

      def day_range
        date.beginning_of_day..date.end_of_day
      end

      def active_today_appointments
        @active_today_appointments ||= appointments_scope
          .includes(:service, :employee_membership)
          .where(starts_at: day_range)
          .where.not(status: Appointment.statuses.values_at(*Appointment::TERMINAL_STATUSES))
          .order(:starts_at)
          .to_a
      end

      def appointment_price_cents(appointment)
        final_price = appointment.final_price_cents.to_i
        return final_price if final_price.positive?

        base_price = appointment.base_price_cents.to_i
        return base_price if base_price.positive?

        appointment.service&.price_cents.to_i
      end

      def comparable_revenue_cents
        @comparable_revenue_cents ||= appointments_scope
          .includes(:service)
          .where(starts_at: (date - 7).all_day)
          .where.not(status: Appointment.statuses.values_at(*Appointment::TERMINAL_STATUSES))
          .to_a
          .sum { |appointment| appointment_price_cents(appointment) }
      end

      def booked_minutes
        @booked_minutes ||= active_today_appointments.sum { |appointment| ((appointment.ends_at - appointment.starts_at) / 60).round }
      end

      def pending_deposit_today_appointments
        @pending_deposit_today_appointments ||= active_today_appointments.select(&:deposit_pending?)
      end

      def pending_deposit_today_count
        pending_deposit_today_appointments.size
      end

      def pending_deposit_today_cents
        pending_deposit_today_appointments.sum { |appointment| appointment.deposit_amount_cents.to_i }
      end

      def today_activity_summary
        details = [ "#{today_appointments_count} #{plural_label(today_appointments_count, 'turno', 'turnos')}" ]
        details << "#{confirmed_today_count} #{plural_label(confirmed_today_count, 'confirmado', 'confirmados')}" if confirmed_today_count.positive?
        if pending_deposit_today_count.positive?
          details << "#{pending_deposit_today_count} #{plural_label(pending_deposit_today_count, 'pendiente', 'pendientes')} de seña"
        end
        details.to_sentence(last_word_connector: " y ")
      end

      def day_finished?
        return @day_finished if defined?(@day_finished)

        @day_finished = date == Time.zone.today && day_availability_end_times.any? && Time.current >= day_availability_end_times.max
      end

      def day_availability_end_times
        @day_availability_end_times ||= begin
          business_rules = business.availability_rules.index_by(&:weekday)
          employees = business.employee_memberships.available_for_booking.includes(:employee_availability_rules).to_a
          rules = if employees.any?
            employees.filter_map do |employee|
              employee_rule = employee.employee_availability_rules.find { |rule| rule.weekday == date.wday }
              employee_rule&.inherits_business_hours? ? business_rules[date.wday] : (employee_rule || business_rules[date.wday])
            end
          else
            [ business_rules[date.wday] ]
          end

          rules.filter_map do |rule|
            next unless rule&.active? && rule.end_time.present?

            Time.zone.local(date.year, date.month, date.day, rule.end_time.hour, rule.end_time.min)
          end
        end
      end

      def available_minutes
        @available_minutes ||= begin
          business_rules = business.availability_rules.index_by(&:weekday)
          employees = business.employee_memberships.available_for_booking.includes(:employee_availability_rules).to_a
          if employees.any?
            employees.sum do |employee|
              employee_rule = employee.employee_availability_rules.find { |rule| rule.weekday == date.wday }
              rule = employee_rule&.inherits_business_hours? ? business_rules[date.wday] : (employee_rule || business_rules[date.wday])
              minutes_for_rule(rule)
            end
          else
            minutes_for_rule(business_rules[date.wday])
          end
        end
      end

      def minutes_for_rule(rule)
        return 0 unless rule&.active? && rule.start_time.present? && rule.end_time.present?

        total = ((rule.end_time.seconds_since_midnight - rule.start_time.seconds_since_midnight) / 60).to_i
        if rule.break_start_time.present? && rule.break_end_time.present?
          total -= ((rule.break_end_time.seconds_since_midnight - rule.break_start_time.seconds_since_midnight) / 60).to_i
        end
        [ total, 0 ].max
      end

      def fillable_gaps
        @fillable_gaps ||= Availability::FillableGaps.new(
          business: business,
          date: date,
          appointments_scope: appointments_scope
        ).call
      rescue StandardError => error
        Rails.logger.warn("Admin::HomeDashboard fillable gaps failed for business #{business.id}: #{error.class} #{error.message}")
        []
      end

      def offerable_gaps
        @offerable_gaps ||= minimum_duration_gaps.select { |gap| offerable_gap?(gap) }
      end

      def minimum_duration_gaps
        @minimum_duration_gaps ||= fillable_gaps.select { |gap| gap.duration_minutes.to_i >= minimum_opportunity_minutes }
      end

      def ranked_offerable_gaps
        @ranked_offerable_gaps ||= offerable_gaps.sort_by { |gap| opportunity_sort_key(gap) }
      end

      def opportunity_candidates
        @opportunity_candidates ||= opportunities.flat_map(&:candidates).uniq(&:id)
      end

      def gap_sentence
        gap = first_offerable_gap
        return unless gap

        "un hueco de #{gap.duration_minutes} minutos a las #{time_label(gap.starts_at)}"
      end

      def short_notice_gap_sentence
        gap = first_fillable_gap
        return unless gap

        "#{fillable_gap_minutes} minutos libres desde las #{time_label(gap.starts_at)}, pero con muy poca anticipación para ofrecerlos"
      end

      def minimum_opportunity_minutes
        business.preferences.fetch("opportunities_minimum_minutes", 30).to_i.clamp(15, 240)
      end

      def maximum_visible_opportunities
        business.preferences.fetch("opportunities_visible_limit", 3).to_i.clamp(1, 6)
      end

      def minimum_offer_lead_minutes
        business.preferences.fetch("opportunities_minimum_lead_minutes", 60).to_i.clamp(0, 480)
      end

      def offerable_gap?(gap)
        return true if date.future?
        return true if minimum_offer_lead_minutes.zero?

        gap.starts_at >= minimum_offer_lead_minutes.minutes.from_now
      end

      def opportunity_sort_key(gap)
        waitlist_priority = gap.waitlist_count.to_i.positive? ? 0 : 1
        candidate_count = suggestions_for(gap).size
        [
          waitlist_priority,
          -candidate_count,
          -gap.service_suggestions.size,
          -gap.duration_minutes.to_i,
          gap.starts_at
        ]
      end

      def build_opportunity(gap, index)
        services = gap.service_suggestions.map { |service| opportunity_service_for(service) }
        candidates = suggestions_for(gap).map { |suggestion| opportunity_candidate_for(suggestion, gap) }
        prices = services.map(&:price_cents).select(&:positive?)
        tone = opportunity_tone(index)

        Opportunity.new(
          key: "gap-#{index + 1}",
          starts_at: gap.starts_at,
          ends_at: gap.ends_at,
          time_label: "#{time_label(gap.starts_at)}-#{time_label(gap.ends_at)}",
          duration_minutes: gap.duration_minutes,
          duration_label: duration_label(gap.duration_minutes),
          employee_membership: gap.employee_membership,
          employee_name: gap.employee_membership&.display_name || "Equipo completo",
          employee_initials: gap.employee_membership&.initials.presence || "HT",
          employee_color: gap.employee_membership&.calendar_color.presence || "#ffded4",
          service_suggestions: services,
          candidates: candidates,
          waitlist_count: gap.waitlist_count.to_i,
          badge_label: opportunity_badge(index, candidates, gap),
          tone: tone,
          potential_label: opportunity_potential_label(prices),
          potential_min_cents: prices.min.to_i,
          potential_max_cents: prices.max.to_i,
          candidate_summary: candidate_summary(candidates)
        )
      end

      def opportunity_service_for(service)
        OpportunityService.new(
          id: service.id,
          key: "service-#{service.id}",
          name: service.name,
          duration_label: duration_label(service.duration_minutes),
          price_label: service.price_cents.to_i.positive? ? service.display_price : nil,
          price_cents: service.price_cents.to_i
        )
      end

      def suggestions_for(gap)
        @suggestions_by_gap ||= {}
        @suggestions_by_gap[gap.object_id] ||= Gaps::SuggestedCustomers.new(business: business, gap: gap, limit: 10).call
      end

      def opportunity_candidate_for(suggestion, gap)
        service = suggestion.service
        OpportunityCandidate.new(
          id: suggestion.customer.id,
          name: suggestion.customer.name.presence || suggestion.customer.phone,
          initials: initials_for(suggestion.customer.name.presence || suggestion.customer.phone),
          phone_label: mask_phone(suggestion.customer.phone),
          service_id: service.id,
          service_key: "service-#{service.id}",
          service_name: service.name,
          reason: suggestion.reason,
          reasons: Array(suggestion.reasons).presence || [ suggestion.reason ],
          compatibility_label: compatibility_label_for(suggestion),
          compatibility_tone: compatibility_tone_for(suggestion),
          last_visit_label: last_visit_label(suggestion.last_visit_at),
          source: suggestion.source
        )
      end

      def message_reason_for(suggestion)
        case suggestion.source
        when "waitlist"
          "Te avisamos porque estabas en lista de espera para este servicio."
        when "follow_up"
          "Como ya pasó un tiempo desde tu última visita, te avisamos por si querés aprovecharlo."
        when "frequent"
          "Te escribimos porque solés reservar este servicio."
        when "inactive"
          "Te escribimos por si querés retomar tus turnos en #{business.name}."
        end
      end

      def opportunity_badge(index, candidates, gap)
        return "Mejor oportunidad" if index.zero? && candidates.any?
        return "Lista de espera" if gap.waitlist_count.to_i.positive?
        return "Sin candidatos" if candidates.blank?

        "Disponible"
      end

      def opportunity_tone(index)
        %w[violet pink blue emerald amber][index % 5]
      end

      def opportunity_potential_label(prices)
        prices = prices.select(&:positive?)
        return nil if prices.blank?

        min = prices.min
        max = prices.max
        return "Valor potencial: #{money(min)}" if min == max

        "Valor potencial: #{money(min)}-#{money(max)}"
      end

      def candidate_summary(candidates)
        return "Todavía sin clientes sugeridos" if candidates.blank?

        counts = candidates.group_by(&:reason).transform_values(&:size)
        counts.first(2).map { |reason, count| "#{count} #{reason.downcase}" }.join(" · ")
      end

      def compatibility_label_for(suggestion)
        return "Lista de espera" if suggestion.source == "waitlist"
        return "Compatibilidad alta" if suggestion.score.to_i >= 80
        return "Compatibilidad media" if suggestion.score.to_i >= 60

        "Compatibilidad baja"
      end

      def compatibility_tone_for(suggestion)
        return "waitlist" if suggestion.source == "waitlist"
        return "high" if suggestion.score.to_i >= 80
        return "medium" if suggestion.score.to_i >= 60

        "low"
      end

      def last_visit_label(value)
        return "Sin visita previa registrada" if value.blank?

        "Última visita #{CustomerDateFormatter.date_label(value)}"
      end

      def duration_label(minutes)
        minutes = minutes.to_i
        return "#{minutes} minutos" if minutes < 60

        hours = minutes / 60
        remainder = minutes % 60
        return "#{hours} h" if remainder.zero?

        "#{hours} h #{remainder} min"
      end

      def initials_for(value)
        value.to_s.split.first(2).map { |part| part.first&.upcase }.join.presence || "?"
      end

      def mask_phone(value)
        digits = PhoneNumber.normalize(value)
        return "Teléfono cargado" if digits.blank?

        visible = digits.last(4)
        "Teléfono •••• #{visible}"
      end

      def day_name(day)
        Business::DAYS.to_h.fetch(day.wday)
      end

      def plural_label(count, singular, plural)
        count.to_i == 1 ? singular : plural
      end
  end
end
