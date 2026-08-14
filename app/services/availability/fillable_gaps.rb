module Availability
  class FillableGaps
    Gap = Struct.new(:starts_at, :ends_at, :duration_minutes, :employee_membership, :service_suggestions, :waitlist_count, keyword_init: true)

    def initialize(business:, date: Time.zone.today, appointments_scope: nil, employee_membership: nil)
      @business = business
      @date = date.to_date
      @appointments_scope = appointments_scope || business.appointments
      @employee_membership = employee_membership
    end

    def call
      calendars.flat_map { |employee, appointments| gaps_for(employee, appointments) }
        .sort_by(&:starts_at)
    end

    private
      attr_reader :business, :date, :appointments_scope, :employee_membership

      def calendars
        if employee_membership.present?
          [ [ employee_membership, appointments_for(employee_membership) ] ]
        elsif business.team_features_available? && active_employees.any?
          active_employees.map { |employee| [ employee, appointments_for(employee) ] }
        else
          [ [ nil, appointments_for(nil) ] ]
        end
      end

      def active_employees
        @active_employees ||= business.employee_memberships.available_for_booking.order(:sort_order, :name).to_a
      end

      def appointments_for(employee)
        relation = appointments_scope.active.where(starts_at: day_range).order(:starts_at)
        employee.present? ? relation.where(employee_membership: employee).to_a : relation.where(employee_membership_id: nil).to_a
      end

      def gaps_for(employee, appointments)
        windows_for(employee).flat_map do |window_start, window_end|
          subtract_appointments(window_start, window_end, appointments, employee).filter_map do |starts_at, ends_at|
            build_gap(starts_at, ends_at, employee)
          end
        end
      end

      def windows_for(employee)
        rule = rule_for(employee)
        return [] unless rule&.active? && rule.start_time.present? && rule.end_time.present?

        start_at = [ time_on_date(rule.start_time), next_usable_time ].max
        end_at = time_on_date(rule.end_time)
        return [] unless end_at > start_at

        break_start = rule.respond_to?(:break_start_time) ? rule.break_start_time : nil
        break_end = rule.respond_to?(:break_end_time) ? rule.break_end_time : nil
        windows = if break_start.present? && break_end.present?
          [ [ start_at, time_on_date(break_start) ], [ time_on_date(break_end), end_at ] ]
        else
          [ [ start_at, end_at ] ]
        end
        windows.filter { |from, to| to > from }
      end

      def rule_for(employee)
        return business.availability_rules.find_by(weekday: date.wday) if employee.blank?

        employee.ensure_availability_rules!
        employee_rule = employee.employee_availability_rules.find_by(weekday: date.wday)
        business_rule = business.availability_rules.find_by(weekday: date.wday)
        employee_rule&.inherits_business_hours? ? business_rule : employee_rule
      end

      def subtract_appointments(window_start, window_end, appointments, employee)
        gaps = []
        cursor = window_start
        blocked_ranges = block_ranges(window_start, window_end, employee)
        busy_ranges = (appointments.map { |appointment| [ appointment.starts_at, appointment.ends_at ] } + blocked_ranges).sort_by(&:first)

        busy_ranges.each do |busy_start, busy_end|
          starts_at = [ busy_start, window_start ].max
          ends_at = [ busy_end, window_end ].min
          next if ends_at <= cursor

          gaps << [ cursor, starts_at ] if starts_at > cursor
          cursor = [ cursor, ends_at ].max
        end

        gaps << [ cursor, window_end ] if window_end > cursor
        gaps
      end

      def block_ranges(window_start, window_end, employee)
        blocks = business.availability_blocks.active.overlapping(window_start, window_end)
        blocks = blocks.where("employee_membership_id IS NULL OR employee_membership_id = ?", employee.id) if employee.present?
        blocks.map { |block| [ block.starts_at, block.ends_at ] }
      end

      def build_gap(starts_at, ends_at, employee)
        minutes = ((ends_at - starts_at) / 60).floor
        return if minutes < 15

        suggestions = matching_services(starts_at, minutes, employee)
        return if suggestions.blank?

        Gap.new(
          starts_at: starts_at,
          ends_at: ends_at,
          duration_minutes: minutes,
          employee_membership: employee,
          service_suggestions: suggestions,
          waitlist_count: waitlist_count_for(suggestions, starts_at)
        )
      end

      def matching_services(starts_at, minutes, employee)
        business.services.publicly_bookable.where("duration_minutes <= ?", minutes).order(duration_minutes: :desc, name: :asc).select do |service|
          employee_allowed?(service, employee) && Availability::AvailableSlots.available?(business:, service:, starts_at:, employee_membership: employee)
        end.first(4)
      end

      def employee_allowed?(service, employee)
        return true if employee.blank?
        return true if service.employee_membership_ids.blank?

        service.employee_membership_ids.include?(employee.id)
      end

      def waitlist_count_for(services, starts_at)
        business.waitlist_entries.visible.where(service_id: services.map(&:id), desired_date: starts_at.to_date).count
      end

      def next_usable_time
        return date.beginning_of_day if date.future?

        current = Time.current
        rounded = current.change(sec: 0)
        rounded + (15 - (rounded.min % 15)).minutes
      end

      def time_on_date(value)
        Time.zone.local(date.year, date.month, date.day, value.hour, value.min)
      end

      def day_range
        date.beginning_of_day..date.end_of_day
      end
  end
end
