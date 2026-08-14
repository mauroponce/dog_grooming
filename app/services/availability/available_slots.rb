module Availability
  class AvailableSlots
    Slot = Struct.new(:starts_at, :ends_at, :employee_membership, :bookable_resource, :reason, keyword_init: true) do
      def time
        starts_at
      end
    end

    STEP = 15.minutes
    HORIZON = 60.days

    def self.for(...)
      new(...).slots
    end

    def self.times(...)
      new(...).times
    end

    def self.available?(business:, service:, starts_at:, employee_membership: nil, online_booking: false)
      new(business:, service:, date: starts_at.to_date, employee_membership:, online_booking:).slots.any? { |slot| slot.starts_at == starts_at }
    end

    def initialize(business:, service:, date:, employee_membership: nil, online_booking: false)
      @business = business
      @service = service
      @date = date.to_date
      @employee_membership = employee_membership
      @online_booking = online_booking
    end

    def slots
      return [] unless service&.active?
      return [] if date < Time.zone.today || date > HORIZON.from_now.to_date
      return [] unless service.available_on_date?(date)
      return [] if closed_for_holiday?

      candidates.flat_map { |candidate| slots_for_candidate(candidate) }
        .sort_by { |slot| [ slot.starts_at, slot.employee_membership&.sort_order.to_i, slot.employee_membership&.name.to_s ] }
    end

    def times
      slots.map(&:starts_at).uniq.sort
    end

    def first_slot
      return nil unless service&.active?
      return nil if date < Time.zone.today || date > HORIZON.from_now.to_date
      return nil unless service.available_on_date?(date)
      return nil if closed_for_holiday?

      candidates.filter_map { |candidate| first_slot_for_candidate(candidate) }
        .min_by { |slot| [ slot.starts_at, slot.employee_membership&.sort_order.to_i, slot.employee_membership&.name.to_s ] }
    end

    private
      attr_reader :business, :service, :date, :employee_membership, :online_booking

      def candidates
        return @candidates if defined?(@candidates)

        return @candidates = [ employee_membership ] if employee_membership.present?
        return @candidates = [ nil ] unless business.team_features_available?

        relation = business.employee_memberships.available_for_booking.includes(:employee_availability_rules).order(:sort_order, :name)
        relation = relation.where(id: service_employee_membership_ids) if service_employee_membership_ids.any?
        professionals = relation.to_a
        @candidates = professionals.presence || [ nil ]
      end

      def slots_for_candidate(candidate)
        return [] unless employee_allowed?(candidate)

        windows_for(candidate).flat_map do |window_start, window_end|
          build_slots_in_window(window_start, window_end, candidate)
        end
      end

      def first_slot_for_candidate(candidate)
        return nil unless employee_allowed?(candidate)

        windows_for(candidate).each do |window_start, window_end|
          current = window_start

          while current + service.duration_minutes.minutes <= window_end
            ends_at = current + service.duration_minutes.minutes
            if current.future?
              resource = available_resource_for(current, ends_at, candidate)
              return slot_for(current, ends_at, candidate, resource) if resource
            end

            current += slot_step
          end
        end

        nil
      end

      def build_slots_in_window(window_start, window_end, candidate)
        slots = []
        current = window_start

        while current + service.duration_minutes.minutes <= window_end
          ends_at = current + service.duration_minutes.minutes
          if current.future?
            resource = available_resource_for(current, ends_at, candidate)
            slots << slot_for(current, ends_at, candidate, resource) if resource
          end
          current += slot_step
        end

        slots
      end

      def slot_for(starts_at, ends_at, candidate, resource = nil)
        Slot.new(starts_at:, ends_at:, employee_membership: candidate, bookable_resource: resource == true ? nil : resource)
      end

      def slot_step
        return STEP unless online_booking

        service.effective_public_start_interval_minutes.minutes
      end

      def windows_for(candidate)
        return [] if base_rule.blank? || !base_rule.active?

        base_windows = windows_from_rule(base_rule)
        professional_rule = rule_for_candidate(candidate)
        professional_windows = if professional_rule.present?
          return [] unless professional_rule.active?

          windows_from_rule(professional_rule)
        else
          base_windows
        end

        service_windows = service_windows_for_day
        intersect_windows(intersect_windows(base_windows, professional_windows), service_windows)
      end

      def rule_for_candidate(candidate)
        return if candidate.blank?

        candidate.ensure_availability_rules!
        rule = employee_rule_for(candidate)
        if rule&.inherits_business_hours? && base_rule.present?
          base_rule
        else
          rule
        end
      end

      def windows_from_rule(rule)
        start_at = time_on_date(rule.start_time)
        end_at = time_on_date(rule.end_time)
        return [] if start_at.blank? || end_at.blank? || end_at <= start_at

        break_start = rule.respond_to?(:break_start_time) ? rule.break_start_time : nil
        break_end = rule.respond_to?(:break_end_time) ? rule.break_end_time : nil
        return [ [ start_at, end_at ] ] if break_start.blank? || break_end.blank?

        break_start_at = time_on_date(break_start)
        break_end_at = time_on_date(break_end)
        [ [ start_at, break_start_at ], [ break_end_at, end_at ] ].select { |from, to| to > from }
      end

      def service_windows_for_day
        return @service_windows_for_day if defined?(@service_windows_for_day)

        return [ [ Time.zone.local(date.year, date.month, date.day, 0, 0), Time.zone.local(date.year, date.month, date.day, 23, 59, 59) ] ] unless service.use_advanced_availability?

        rules = if service.association(:service_availability_rules).loaded?
          service.service_availability_rules.select { |rule| rule.active? && rule.weekday == date.wday }
        else
          service.service_availability_rules.active.where(weekday: date.wday).to_a
        end
        @service_windows_for_day = rules.map { |rule| [ time_on_date(rule.start_time), time_on_date(rule.end_time) ] }.select { |from, to| from.present? && to.present? && to > from }
      end

      def intersect_windows(left, right)
        left.flat_map do |left_start, left_end|
          right.filter_map do |right_start, right_end|
            starts_at = [ left_start, right_start ].max
            ends_at = [ left_end, right_end ].min
            [ starts_at, ends_at ] if ends_at > starts_at
          end
        end
      end

      def time_on_date(value)
        return if value.blank?

        Time.zone.local(date.year, date.month, date.day, value.hour, value.min)
      end

      def available_resource_for(starts_at, ends_at, candidate)
        return false if appointment_overlap?(starts_at, ends_at, candidate)
        return false if blocked?(starts_at, ends_at, candidate)

        availability = Resources::Availability.new(business:, service:, starts_at:, ends_at:)
        return true unless availability.required?

        availability.first_available || false
      end

      def appointment_overlap?(starts_at, ends_at, candidate)
        employee_id = candidate&.id
        day_appointments.any? do |appointment|
          appointment.employee_membership_id == employee_id &&
            appointment.starts_at < ends_at &&
            appointment.ends_at > starts_at
        end
      end

      def blocked?(starts_at, ends_at, candidate)
        employee_id = candidate&.id
        day_block_occurrences.any? do |occurrence|
          next false if occurrence.bookable_resource_id.present?
          next false if employee_id.present? && occurrence.employee_membership_id.present? && occurrence.employee_membership_id != employee_id
          next false if employee_id.blank? && occurrence.employee_membership_id.present?

          occurrence.starts_at < ends_at && occurrence.ends_at > starts_at
        end
      end

      def closed_for_holiday?
        return @closed_for_holiday if defined?(@closed_for_holiday)

        @closed_for_holiday = business.holidays.closed.exists?(date:)
      end

      def employee_allowed?(candidate)
        return true if candidate.blank? && !booking_enabled_employee_exists?
        return true if candidate.blank? && !business.team_features_available?
        return false if candidate.blank? && business.team_features_available?
        return false unless candidate.business_id == business.id
        return false unless candidate.active? && candidate.archived_at.blank?
        return true if service_employee_membership_ids.blank?

        service_employee_membership_ids.include?(candidate.id)
      end

      def base_rule
        return @base_rule if defined?(@base_rule)

        @base_rule = business.availability_rules.find_by(weekday: date.wday)
      end

      def employee_rule_for(candidate)
        @employee_rules_by_candidate_id ||= {}
        return @employee_rules_by_candidate_id[candidate.id] if @employee_rules_by_candidate_id.key?(candidate.id)

        rules = candidate.employee_availability_rules
        @employee_rules_by_candidate_id[candidate.id] = if rules.loaded?
          rules.find { |rule| rule.weekday == date.wday }
        else
          rules.find_by(weekday: date.wday)
        end
      end

      def service_employee_membership_ids
        @service_employee_membership_ids ||= service.employee_membership_ids
      end

      def day_start
        @day_start ||= Time.zone.local(date.year, date.month, date.day)
      end

      def day_end
        @day_end ||= day_start.end_of_day
      end

      def day_appointments
        @day_appointments ||= business.appointments.active
          .where("starts_at < ? AND ends_at > ?", day_end, day_start)
          .select(:id, :employee_membership_id, :starts_at, :ends_at)
          .to_a
      end

      def day_block_occurrences
        @day_block_occurrences ||= AvailabilityBlock.occurrences_for(
          business: business,
          starts_at: day_start,
          ends_at: day_end,
          include_online_bookable: !online_booking
        )
      end

      def booking_enabled_employee_exists?
        return @booking_enabled_employee_exists if defined?(@booking_enabled_employee_exists)

        @booking_enabled_employee_exists = business.employee_memberships.available_for_booking.exists?
      end
  end
end
