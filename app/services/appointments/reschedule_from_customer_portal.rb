module Appointments
  class RescheduleFromCustomerPortal
    def self.call(...)
      new(...).call
    end

    def initialize(appointment:, starts_at:)
      @appointment = appointment
      @starts_at = starts_at
    end

    def call
      business.with_lock do
        appointment.lock!
        validate_rescheduling_window!
        validate_new_starts_at!

        professional = assign_first_available_professional!
        ensure_slot_is_available!(professional)
        resource = available_resource_for!
        previous_starts_at = appointment.starts_at

        appointment.update!(
          starts_at: starts_at,
          ends_at: ends_at,
          employee_membership: professional,
          branch: professional&.branch || appointment.branch,
          bookable_resource: resource,
          internal_notes: rescheduling_note(previous_starts_at, professional)
        )
      end

      appointment
    rescue Bookings::AssignProfessionalService::UnavailableProfessional, ActiveRecord::RecordInvalid => error
      raise UnavailableSlot, error.message.presence || "Ese horario ya no está disponible."
    end

    private
      attr_reader :appointment, :starts_at

      def business
        appointment.business
      end

      def service
        appointment.service
      end

      def ends_at
        starts_at + service.duration_minutes.minutes
      end

      def validate_rescheduling_window!
        return if appointment.customer_portal_reschedulable?

        raise UnavailableSlot, "Este turno ya no se puede reprogramar desde el portal."
      end

      def validate_new_starts_at!
        raise UnavailableSlot, "Seleccioná un horario disponible." if starts_at.blank?
        raise UnavailableSlot, "Elegí un horario distinto al actual." if starts_at.to_i == appointment.starts_at.to_i
      end

      def assign_first_available_professional!
        Bookings::AssignProfessionalService.call(
          business: business,
          service: service,
          starts_at: starts_at,
          assignment_strategy: "first_available",
          customer_profile: appointment.customer_profile,
          lock: true,
          online_booking: true,
          excluding_appointment: appointment
        )
      end

      def ensure_slot_is_available!(professional)
        return if Availability::Slots.public_available?(business: business, service: service, starts_at: starts_at, employee_membership: professional, excluding_appointment: appointment)

        raise UnavailableSlot, "Ese horario ya no está disponible."
      end

      def available_resource_for!
        availability = Resources::Availability.new(
          business: business,
          service: service,
          starts_at: starts_at,
          ends_at: ends_at,
          excluding_appointment: appointment
        )
        return unless availability.required?

        availability.first_available(lock: true) || raise(UnavailableSlot, "Ese horario ya no está disponible.")
      end

      def rescheduling_note(previous_starts_at, professional)
        note = "Reprogramado desde portal de cliente. Turno anterior: #{previous_starts_at.in_time_zone.strftime('%d/%m/%Y %H:%M')}."
        note += " Profesional asignado: #{professional.name}." if professional.present?

        [ appointment.internal_notes, note ].compact_blank.join("\n")
      end
  end
end
