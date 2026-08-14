module Gaps
  class SuggestedCustomers
    Suggestion = Struct.new(:customer, :service, :reason, :reasons, :score, :source, :last_visit_at, :whatsapp_url, keyword_init: true)

    def initialize(business:, gap:, limit: 5)
      @business = business
      @gap = gap
      @limit = limit
    end

    def call
      (waitlist_suggestions + follow_up_suggestions + frequent_suggestions + inactive_suggestions)
        .uniq { |suggestion| [ suggestion.customer.id, suggestion.service.id ] }
        .sort_by { |suggestion| -suggestion.score.to_i }
        .first(limit)
    end

    private
      attr_reader :business, :gap, :limit

      def waitlist_suggestions
      business.waitlist_entries.visible
          .includes(:customer_profile, :service)
          .where(service: matching_services, desired_date: gap.starts_at.to_date)
          .filter_map do |entry|
            next if entry.customer_profile.blank?
            next unless entry_matches_gap?(entry)

            build(
              entry.customer_profile,
              entry.service,
              "Está en lista de espera",
              score: 95,
              source: "waitlist",
              extra_reasons: [ "Franja compatible", entry.employee_membership_id.present? ? "Pidió este profesional" : "Acepta cualquier profesional" ]
            )
          end
      end

      def follow_up_suggestions
        business.customer_reminders.pending
          .includes(:customer_profile, :service)
          .where(reminder_type: "service_follow_up", service: matching_services)
          .order(:remind_at)
          .filter_map do |reminder|
            build(
              reminder.customer_profile,
              reminder.service,
              "Tiene seguimiento pendiente",
              score: 86,
              source: "follow_up",
              extra_reasons: [ "Mantenimiento sugerido", "Sin turno próximo" ]
            )
          end
      end

      def frequent_suggestions
        rows = business.appointments
          .where(status: Appointment.statuses.values_at("confirmed", "completed"))
          .where("starts_at < ?", Time.current)
          .where(service: matching_services)
          .where.not(customer_profile_id: nil)
          .group(:customer_profile_id, :service_id)
          .having("COUNT(*) >= 2")
          .count
          .sort_by { |_ids, count| -count }
          .first(limit)

        rows.filter_map do |(customer_id, service_id), _count|
          customer = business.customer_profiles.find_by(id: customer_id)
          service = matching_services.find { |item| item.id == service_id }
          build(
            customer,
            service,
            "Suele reservar este servicio",
            score: 72,
            source: "frequent",
            extra_reasons: [ "Cliente frecuente", "Sin turno próximo" ]
          )
        end
      end

      def inactive_suggestions
        cutoff = 60.days.ago
        last_by_customer = business.appointments
          .where(status: Appointment.statuses.values_at("confirmed", "completed"))
          .where("starts_at < ?", Time.current)
          .where.not(customer_profile_id: nil)
          .group(:customer_profile_id)
          .maximum(:starts_at)
        business.customer_profiles.where(id: last_by_customer.select { |_id, last_at| last_at < cutoff }.keys).limit(limit).filter_map do |customer|
          build(
            customer,
            matching_services.first,
            "Hace más de 60 días que no vuelve",
            score: 58,
            source: "inactive",
            extra_reasons: [ "Cliente inactivo", "Sin turno próximo" ]
          )
        end
      end

      def build(customer, service, reason, score:, source:, extra_reasons: [])
        return if customer.blank? || service.blank?
        return unless customer.business_id == business.id
        return if customer.blocked?
        return if customer.phone.blank? || PhoneNumber.normalize(customer.phone).blank?
        return if future_equivalent_appointment?(customer, service)
        return if overlapping_customer_appointment?(customer)
        return if recently_contacted?(customer, service)

        last_visit_at = last_visit_for(customer, service)
        reasons = [ reason, *extra_reasons ]
        reasons << "Última visita hace #{days_since(last_visit_at)} días" if last_visit_at.present?
        reasons << "Se atiende con #{gap.employee_membership.display_name}" if gap.employee_membership.present? && customer_seen_with_employee?(customer)

        Suggestion.new(
          customer: customer,
          service: service,
          reason: reason,
          reasons: reasons.compact_blank.uniq.first(4),
          score: score,
          source: source,
          last_visit_at: last_visit_at,
          whatsapp_url: WhatsApp::MessageBuilder.new(
            business: business,
            template_key: "gap_offer",
            customer: customer,
            service: service,
            gap: gap
          ).url(phone: customer.phone)
        )
      end

      def matching_services
        @matching_services ||= gap.service_suggestions
      end

      def entry_matches_gap?(entry)
        return false if entry.employee_membership_id.present? && gap.employee_membership.present? && entry.employee_membership_id != gap.employee_membership.id
        return true if entry.preferred_time_windows.blank?

        WaitlistEntry.time_window_covers?(entry.preferred_time_windows, gap.starts_at)
      end

      def future_equivalent_appointment?(customer, service)
        business.appointments.active.joins(:service)
          .where(customer_profile: customer)
          .where("appointments.starts_at >= ?", Time.current)
          .where("appointments.service_id = :service_id OR services.category = :category", service_id: service.id, category: service.category)
          .exists?
      end

      def overlapping_customer_appointment?(customer)
        business.appointments.active
          .where(customer_profile: customer)
          .where("starts_at < ? AND ends_at > ?", gap.ends_at, gap.starts_at)
          .exists?
      end

      def recently_contacted?(customer, service)
        business.sales_opportunities
          .where(customer_profile: customer, service: service)
          .where.not(contacted_at: nil)
          .where("contacted_at >= ?", 7.days.ago)
          .exists?
      end

      def last_visit_for(customer, service)
        business.appointments
          .where(customer_profile: customer, service: service)
          .where(status: Appointment.statuses.values_at("confirmed", "completed"))
          .where("starts_at < ?", Time.current)
          .maximum(:starts_at)
      end

      def customer_seen_with_employee?(customer)
        return false if gap.employee_membership.blank?

        business.appointments
          .where(customer_profile: customer, employee_membership: gap.employee_membership)
          .where(status: Appointment.statuses.values_at("confirmed", "completed"))
          .exists?
      end

      def days_since(time)
        return if time.blank?

        [ ((Time.current - time) / 1.day).floor, 0 ].max
      end
  end
end
