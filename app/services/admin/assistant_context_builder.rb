module Admin
  class AssistantContextBuilder
    def initialize(business:)
      @business = business
      @now = Time.zone.now
      @today = Time.zone.today
    end

    def call
      {
        generated_at: now.iso8601,
        current_date: today.iso8601,
        business: business_snapshot,
        stats: stats_snapshot,
        today_appointments: appointments_snapshot(today_appointments, limit: 18),
        upcoming_appointments: appointments_snapshot(upcoming_appointments, limit: 25),
        pending_deposit_reviews: appointments_snapshot(pending_deposit_reviews, limit: 12),
        waiting_list: waitlist_snapshot,
        services: services_snapshot,
        top_services_last_30_days: top_services_snapshot,
        customers: customers_snapshot,
        team: team_snapshot,
        opening_hours: opening_hours_snapshot,
        blocked_times_next_7_days: blocked_times_snapshot,
        fillable_gaps_today: fillable_gaps_snapshot
      }
    end

    def to_prompt
      JSON.pretty_generate(call)
    end

    private
      attr_reader :business, :now, :today

      def business_snapshot
        {
          id: business.id,
          name: business.name,
          slug: business.slug,
          industry: business.industry_label,
          city: business.city,
          province: business.province,
          public_url: PublicUrls.url(:business, business)
        }
      end

      def stats_snapshot
        {
          appointments_today: today_appointments.count,
          confirmed_today: today_appointments.confirmed.count,
          pending_deposit_reviews: pending_deposit_reviews.count,
          waiting_list_entries: business.waitlist_entries.pending.count,
          active_customers: business.customer_profiles.where(blocked_at: nil).count,
          new_customers_last_30_days: business.customer_profiles.where(created_at: last_30_days_range).count,
          active_services: business.services.active.count,
          public_services: business.services.publicly_bookable.count,
          active_team_members: business.employee_memberships.available_for_booking.count,
          estimated_revenue_today: money(active_appointments_between(today.all_day).sum(:final_price_cents)),
          estimated_revenue_next_7_days: money(active_appointments_between(now..7.days.from_now).sum(:final_price_cents)),
          canceled_last_30_days: business.appointments.where(status: Appointment.statuses[:canceled], starts_at: last_30_days_range).count,
          no_shows_last_30_days: business.appointments.where(status: Appointment.statuses[:no_show], starts_at: last_30_days_range).count
        }
      end

      def appointments_snapshot(relation, limit:)
        relation.limit(limit).map do |appointment|
          {
            customer: appointment.customer_name,
            service: appointment.service&.name,
            professional: appointment.employee_membership&.name || "Sin profesional asignado",
            starts_at: appointment.starts_at&.iso8601,
            starts_at_label: appointment.starts_at ? I18n.l(appointment.starts_at, format: "%A %-d/%m %H:%M") : nil,
            duration_minutes: ((appointment.ends_at - appointment.starts_at) / 60).round,
            status: appointment.status_label,
            deposit_status: appointment.deposit_status_label,
            expected_deposit: money(appointment.deposit_amount_cents),
            final_price: money(appointment.final_price_cents)
          }
        end
      end

      def waitlist_snapshot
        {
          waiting: business.waitlist_entries.pending.count,
          offered: business.waitlist_entries.notified.count,
          next_entries: business.waitlist_entries.visible.includes(:service, :employee_membership).order(:desired_date, :created_at).limit(10).map do |entry|
            {
              customer: entry.client_name,
              service: entry.service&.name,
              professional: entry.employee_membership&.name || "Sin preferencia",
              desired_date: entry.desired_date&.iso8601,
              time_windows: Array(entry.preferred_time_windows).map { |window| WaitlistEntry.time_window_label(window) },
              status: entry.status
            }
          end
        }
      end

      def services_snapshot
        business.services.active.includes(:service_category).order(:sort_order, :name).limit(30).map do |service|
          {
            name: service.name,
            category: service.service_category&.name || service.category,
            duration_minutes: service.duration_minutes,
            price: money(service.price_cents),
            deposit_required: service.deposit_required?,
            expected_deposit: money(service.expected_deposit_amount_cents),
            visibility: service.visibility_mode,
            public_visible: service.public?
          }
        end
      end

      def top_services_snapshot
        appointment_counts = business.appointments
          .where(starts_at: last_30_days_range)
          .where.not(status: Appointment.statuses.values_at(*Appointment::TERMINAL_STATUSES))
          .group(:service_id)
          .count

        services = business.services.where(id: appointment_counts.keys).index_by(&:id)

        appointment_counts.sort_by { |_service_id, count| -count }.first(8).map do |service_id, count|
          service = services[service_id]
          next unless service

          {
            service: service.name,
            category: service.category,
            appointments: count,
            estimated_revenue: money(
              business.appointments.where(service_id: service_id, starts_at: last_30_days_range)
                .where.not(status: Appointment.statuses.values_at(*Appointment::TERMINAL_STATUSES))
                .sum(:final_price_cents)
            )
          }
        end.compact
      end

      def customers_snapshot
        {
          total: business.customer_profiles.count,
          blocked: business.customer_profiles.where.not(blocked_at: nil).count,
          with_no_shows: business.customer_profiles.where("no_show_count > 0").count,
          recent: business.customer_profiles.order(created_at: :desc).limit(10).map do |customer|
            {
              name: customer.name,
              phone_present: customer.phone.present?,
              email_present: customer.email.present?,
              created_at: customer.created_at.iso8601,
              cancellations: customer.total_cancellations_count,
              no_shows: customer.no_show_count
            }
          end
        }
      end

      def team_snapshot
        business.employee_memberships.ordered.limit(20).map do |employee|
          {
            name: employee.name,
            status: employee.status,
            profession: employee.specialty,
            appointments_today: today_appointments.where(employee_membership_id: employee.id).count
          }
        end
      end

      def opening_hours_snapshot
        rules = business.availability_rules.order(:weekday).index_by(&:weekday)
        Business::DAYS.map do |weekday, day_name|
          rule = rules[weekday]
          if rule&.active?
            {
              day: day_name,
              status: "Abierto",
              from: time_label(rule.start_time),
              to: time_label(rule.end_time),
              break_from: time_label(rule.break_start_time),
              break_to: time_label(rule.break_end_time)
            }
          else
            {
              day: day_name,
              status: "Cerrado"
            }
          end
        end
      end

      def blocked_times_snapshot
        AvailabilityBlock.occurrences_for(
          business: business,
          starts_at: now.beginning_of_day,
          ends_at: 7.days.from_now.end_of_day,
          include_online_bookable: false
        ).first(20).map do |occurrence|
          employee = business.employee_memberships.find { |membership| membership.id == occurrence.employee_membership_id }
          {
            title: occurrence.reason,
            professional: employee&.name || "Todo el centro",
            starts_at: occurrence.starts_at.iso8601,
            ends_at: occurrence.ends_at.iso8601,
            duration_minutes: occurrence.duration_minutes,
            recurrence: occurrence.recurrence
          }
        end
      end

      def fillable_gaps_snapshot
        Availability::FillableGaps.new(business: business, date: today).call.first(12).map do |gap|
          suggestions = Gaps::SuggestedCustomers.new(business: business, gap: gap, limit: 8).call

          {
            date: today.iso8601,
            time: "#{time_label(gap.starts_at)}-#{time_label(gap.ends_at)}",
            starts_at: gap.starts_at.iso8601,
            ends_at: gap.ends_at.iso8601,
            duration_minutes: gap.duration_minutes,
            professional: gap.employee_membership&.display_name || gap.employee_membership&.name || "Todo el centro",
            waitlist_count: gap.waitlist_count.to_i,
            services: gap.service_suggestions.map do |service|
              {
                name: service.name,
                duration_minutes: service.duration_minutes,
                price: money(service.price_cents)
              }
            end,
            suggested_customers: suggestions.map do |suggestion|
              {
                customer: suggestion.customer.name.presence || suggestion.customer.phone,
                service: suggestion.service.name,
                reason: suggestion.reason,
                reasons: suggestion.reasons,
                source: suggestion.source,
                last_visit_at: suggestion.last_visit_at&.iso8601
              }
            end
          }
        end
      rescue StandardError => error
        Rails.logger.warn("Admin assistant fillable gaps context failed for business #{business.id}: #{error.class} #{error.message}")
        []
      end

      def today_appointments
        @today_appointments ||= business.appointments.includes(:service, :employee_membership).where(starts_at: today.all_day).order(:starts_at)
      end

      def upcoming_appointments
        business.appointments.includes(:service, :employee_membership).active.where(starts_at: now..7.days.from_now).order(:starts_at)
      end

      def pending_deposit_reviews
        business.appointments.includes(:service, :employee_membership).awaiting_deposit_review.order(:starts_at)
      end

      def active_appointments_between(range)
        business.appointments.active.where(starts_at: range)
      end

      def last_30_days_range
        30.days.ago..now
      end

      def money(cents)
        value = cents.to_i
        return "$0" if value.zero?

        "$#{(value / 100).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
      end

      def time_label(value)
        value&.strftime("%H:%M")
      end
  end
end
