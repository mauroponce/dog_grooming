module Admin
  class AvailabilityBlocksController < BaseController
    def create
      block = build_block
      authorize block, :create?

      if block.save
        render json: { blocks: block_occurrences_payload(block) }, status: :created
      else
        render json: { errors: block.errors.full_messages }, status: :unprocessable_entity
      end
    rescue Date::Error, ArgumentError
      render json: { errors: [ "Revisá fecha y horarios." ] }, status: :unprocessable_entity
    end

    def destroy
      block = policy_scope(AvailabilityBlock).find(series_id_from_param)
      authorize block, :destroy?
      block.update!(cancelled_at: Time.current)

      render json: { id: params[:id].to_s, seriesId: block.id.to_s }
    end

    private
      def build_block
        attrs = block_params.to_h.with_indifferent_access
        date = Date.iso8601(attrs[:date].to_s)
        starts_at = time_on_date(date, attrs[:start_time])
        ends_at = time_on_date(date, attrs[:end_time])
        ends_at += 1.day if ends_at <= starts_at
        employee = selected_employee(attrs[:employee_membership_id])

        @business.availability_blocks.new(
          starts_at: starts_at,
          ends_at: ends_at,
          employee_membership: employee,
          block_type: employee.present? ? "professional_block" : "center_block",
          reason: attrs[:title].presence || attrs[:reason].presence || "No disponible",
          description: attrs[:description],
          recurrence: attrs[:recurrence].presence_in(AvailabilityBlock::RECURRENCES.keys) || "none",
          recurrence_ends_on: attrs[:recurrence_ends_on].presence,
          online_booking_allowed: ActiveModel::Type::Boolean.new.cast(attrs[:online_booking_allowed]),
          created_by: current_user
        )
      end

      def block_params
        params.require(:availability_block).permit(
          :title,
          :reason,
          :description,
          :date,
          :start_time,
          :end_time,
          :employee_membership_id,
          :recurrence,
          :recurrence_ends_on,
          :online_booking_allowed
        )
      end

      def selected_employee(employee_id)
        membership = current_employee_membership
        return membership if membership.present? && !membership.can?("can_view_all_bookings")
        return if employee_id.blank? || employee_id.to_s == "center"

        @business.employee_memberships.available_for_booking.find(employee_id)
      end

      def time_on_date(date, value)
        hour, minute = value.to_s.split(":").map(&:to_i)
        raise ArgumentError if hour.nil? || minute.nil? || hour > 23 || minute > 59

        Time.zone.local(date.year, date.month, date.day, hour, minute)
      end

      def block_occurrences_payload(block)
        range = response_range_for(block)
        block.occurrences_between(range.begin, range.end).map { |occurrence| block_payload(occurrence) }
      end

      def response_range_for(block)
        range_start = parse_optional_date(params[:range_start])&.beginning_of_day || block.starts_at.beginning_of_month.beginning_of_week(:monday)
        range_end = parse_optional_date(params[:range_end])&.end_of_day || block.starts_at.end_of_month.end_of_week(:monday)
        range_start..range_end
      end

      def parse_optional_date(value)
        return if value.blank?

        Date.iso8601(value.to_s)
      end

      def block_payload(occurrence)
        {
          id: occurrence.id.to_s,
          seriesId: occurrence.series_id.to_s,
          employeeId: occurrence.employee_membership_id&.to_s,
          startsAt: occurrence.starts_at.iso8601,
          dateISO: occurrence.starts_at.to_date.iso8601,
          start: time_label(occurrence.starts_at),
          finish: time_label(occurrence.ends_at),
          duration: occurrence.duration_minutes,
          reason: occurrence.reason.presence || "No disponible",
          description: occurrence.description,
          recurrence: occurrence.recurrence,
          recurrenceLabel: AvailabilityBlock::RECURRENCES.fetch(occurrence.recurrence, "No se repite"),
          onlineBookingAllowed: occurrence.online_booking_allowed,
          color: "#e5e7eb"
        }
      end

      def time_label(value)
        value.in_time_zone.strftime("%H:%M")
      end

      def series_id_from_param
        params[:id].to_s.split(":").first
      end
  end
end
