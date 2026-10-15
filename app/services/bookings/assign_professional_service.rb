module Bookings
  class AssignProfessionalService
    class UnavailableProfessional < StandardError; end

    def self.call(...)
      new(...).call
    end

    def initialize(business:, service:, starts_at:, preferred_professional: nil, assignment_strategy: nil, customer_profile: nil, lock: true, online_booking: false, excluding_appointment: nil)
      @excluding_appointment = excluding_appointment
      @business = business
      @service = service
      @starts_at = starts_at
      @preferred_professional = preferred_professional
      @assignment_strategy = assignment_strategy.presence
      @customer_profile = customer_profile
      @lock = lock
      @online_booking = online_booking
    end

    def call
      return nil unless business.team_features_available?
      return nil if candidate_professionals.blank?

      if preferred_professional.present?
        return preferred_professional if available?(preferred_professional)

        raise UnavailableProfessional, "#{preferred_professional.name} no tiene disponibilidad para ese horario"
      end

      selected_professional = select_available_professional
      raise UnavailableProfessional, "No hay profesionales disponibles para ese horario" if selected_professional.blank?

      selected_professional
    end

    private
      attr_reader :business, :service, :starts_at, :preferred_professional, :assignment_strategy, :customer_profile, :lock, :online_booking

      def select_available_professional
        return habitual_professional || first_available_professional if normalized_assignment_strategy == "habitual_professional"
        return balanced_professional if normalized_assignment_strategy == "balanced_rotation"
        return least_daily_load_professional if normalized_assignment_strategy == "least_daily_load"

        first_available_professional
      end

      def normalized_assignment_strategy
        @normalized_assignment_strategy ||= begin
          fallback = if online_booking
            business.public_booking_allow_professional_selection? ? Business::PUBLIC_BOOKING_ASSIGNMENT_STRATEGY_DEFAULT : business.public_booking_assignment_strategy
          else
            "least_daily_load"
          end
          Business.normalize_public_booking_assignment_strategy(assignment_strategy.presence || fallback)
        end
      end

      def available_professionals
        @available_professionals ||= candidate_professionals.select { |professional| available?(professional) }
      end

      def first_available_professional
        available_professionals.first
      end

      def balanced_professional
        available_professionals.min_by { |professional| [ total_load(professional), professional.sort_order.to_i, professional.name ] }
      end

      def least_daily_load_professional
        available_professionals.min_by { |professional| [ daily_load(professional), professional.sort_order.to_i, professional.name ] }
      end

      def habitual_professional
        return if customer_profile.blank?

        historical_statuses = Appointment.statuses.values_at("confirmed", "completed", "pending_confirmation")
        counts = customer_profile.appointments
          .where(employee_membership: available_professionals)
          .where(status: historical_statuses)
          .where("starts_at < ?", starts_at)
          .group(:employee_membership_id)
          .count
        return if counts.blank?

        available_professionals
          .select { |professional| counts[professional.id].to_i.positive? }
          .min_by { |professional| [ -counts[professional.id].to_i, professional.sort_order.to_i, professional.name ] }
      end

      def candidate_professionals
        @candidate_professionals ||= begin
          relation = business.employee_memberships.available_for_booking.order(:sort_order, :name)
          relation = relation.where(id: service.employee_membership_ids) if service.employee_membership_ids.any?
          relation = relation.lock if lock
          relation.to_a
        end
      end

      def available?(professional)
        Availability::AvailableSlots.available?(
          business: business,
          service: service,
          starts_at: starts_at,
          employee_membership: professional,
          online_booking: online_booking,
          excluding_appointment: @excluding_appointment
        )
      end

      def daily_load(professional)
        business.appointments.active
          .where(employee_membership: professional)
          .where(starts_at: starts_at.beginning_of_day..starts_at.end_of_day)
          .count
      end

      def total_load(professional)
        business.appointments.active
          .where(employee_membership: professional)
          .count
      end
  end
end
