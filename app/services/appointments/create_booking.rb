module Appointments
  class CreateBooking
    def self.call(...)
      new(...).call
    end

    def initialize(business:, service:, starts_at:, customer_name:, customer_phone:, customer_email: nil, pet: nil, pet_id: nil, pet_name: nil, pet_breed: nil, pet_sex: nil, pet_birth_date: nil, pet_notes: nil, pet_coat_type: nil, pet_coat_details: nil, source: :public_booking, notes: nil, add_on_service_ids: [], extra_ids: [], branch: nil, employee_membership: nil, deposit_receipt: nil, payment_method: nil)
      @business = business
      @service = service
      @starts_at = starts_at
      @customer_name = customer_name
      @customer_phone = customer_phone
      @customer_email = customer_email
      @pet = pet
      @pet_id = pet_id
      @pet_name = pet_name
      @pet_breed = pet_breed
      @pet_sex = pet_sex
      @pet_birth_date = pet_birth_date
      @pet_notes = pet_notes
      @pet_coat_type = pet_coat_type
      @pet_coat_details = pet_coat_details
      @source = source
      @notes = notes
      @add_on_service_ids = Array(add_on_service_ids).reject(&:blank?)
      @extra_ids = Array(extra_ids).reject(&:blank?)
      @branch = branch
      @employee_membership = employee_membership
      @deposit_receipt = deposit_receipt
      @payment_method = payment_method
    end

    def call
      validate_payment_configuration!

      appointment = business.with_lock do
        profile_for_assignment = customer_profile_for_assignment
        raise BlockedCustomer, "Este teléfono está bloqueado para reservas en línea" if profile_for_assignment&.blocked?

        assigned_employee = assign_professional!(customer_profile: profile_for_assignment)
        raise UnavailableSlot, "El turno ya no está disponible" unless slot_available_for_source?(assigned_employee)

        profile = find_or_update_customer_profile!
        raise BlockedCustomer, "Este teléfono está bloqueado para reservas en línea" if profile.blocked?
        pet = pet_for_profile(profile)

        resource = available_resource_for_service!
        pricing = pricing_for
        appointment = business.appointments.create!(
          service: service,
          customer_profile: profile,
          pet: pet,
          bookable_resource: resource,
          branch: branch,
          employee_membership: assigned_employee,
          customer_name: customer_name,
          customer_phone: customer_phone,
          customer_email: customer_email,
          starts_at: starts_at,
          source: source,
          notes: notes,
          customer_notes: notes,
          base_price_cents: pricing.fetch(:base_price_cents),
          final_price_cents: pricing.fetch(:final_price_cents),
          payment_expires_at: service.deposit_required? ? Time.current + service.deposit_payment_deadline_minutes.minutes : nil,
          discount_percentage: pricing.fetch(:discount_percentage)
        )
        create_addons!(appointment, pricing.fetch(:add_ons))
        create_extras!(appointment, pricing.fetch(:extras))
        appointment
      end

      configure_payment!(appointment)
      appointment.update!(status: :confirmed, confirmed_at: Time.current) unless appointment.deposit_required?
      schedule_pending_deposit_expiration!(appointment) if appointment.pending_deposit? || appointment.pending_payment?
      SendAppointmentReservedMessageJob.perform_later(appointment) if appointment.public_booking?
      appointment
    rescue StandardError => error
      if appointment&.persisted? && !appointment.canceled?
        appointment.update!(
          status: :canceled,
          canceled_at: Time.current,
          canceled_by: "system",
          cancellation_reason: "No se pudo preparar la reserva: #{error.message}",
          canceled_late: false
        )
      end
      raise
    end

    private
      attr_reader :business, :service, :starts_at, :customer_name, :customer_phone, :customer_email, :pet, :pet_id, :pet_name, :pet_breed, :pet_sex, :pet_birth_date, :pet_notes, :pet_coat_type, :pet_coat_details, :source, :notes, :add_on_service_ids, :extra_ids, :branch, :employee_membership, :deposit_receipt, :payment_method

      def validate_payment_configuration!
        if business.simultaneous_capacity.present? && source.to_s == "public_booking"
          raise ArgumentError, "La reserva online requiere seña por Mercado Pago." unless service.deposit_required? && selected_payment_method == "mercado_pago"
        end
        return unless service[:deposit_required]

        raise ArgumentError, "El servicio requiere seña, pero no tiene valor de seña configurado." unless service.deposit_amount_cents.to_i.positive?

        case selected_payment_method
        when "mercado_pago"
          raise ArgumentError, "Mercado Pago no está disponible para esta reserva." unless mercado_pago_payment_available?
        when "manual_transfer"
          raise ArgumentError, "Este servicio pide comprobante, pero el negocio todavía no configuró una cuenta para cobrar." unless service.manual_payment_configured?
        else
          raise ArgumentError, "Elegí un método de pago para reservar."
        end
      end

      def configure_payment!(appointment)
        return unless service.deposit_required?

        payment_amount_cents = appointment.calculated_deposit_amount_cents
        raise ArgumentError, "El servicio requiere pago para reservar, pero no tiene monto configurado." if payment_amount_cents <= 0

        if selected_payment_method == "mercado_pago"
          raise ArgumentError, "Mercado Pago no está disponible para esta reserva." unless mercado_pago_payment_available?

          appointment.mark_mercado_pago_payment_pending!(
            amount_cents: payment_amount_cents,
            charge_mode: "deposit"
          )
          return
        end

        raise ArgumentError, "El negocio todavía no configuró una cuenta para cobrar señas." unless service.manual_payment_configured?

        appointment.mark_manual_deposit_pending!(amount_cents: payment_amount_cents, charge_mode: "deposit")
        return if deposit_receipt.blank?
        DepositProofs::ReplaceService.new(booking: appointment, file: deposit_receipt).call
      end

      def schedule_pending_deposit_expiration!(appointment)
        ExpirePendingDepositBookingsJob.set(wait: appointment.service.deposit_payment_deadline_minutes.minutes).perform_later
      end

      def selected_payment_method
        @selected_payment_method ||= begin
          normalized = payment_method.to_s
          normalized = "manual_transfer" if normalized == "manual_proof"
          normalized = nil unless normalized.in?(Business::PAYMENT_METHODS)
          normalized ||= available_payment_methods.first unless source.to_s == "public_booking"
          normalized
        end
      end

      def available_payment_methods
        methods = []
        methods << "manual_transfer" if business.manual_transfer_payment_enabled? && service.manual_payment_configured?
        methods << "mercado_pago" if mercado_pago_payment_available?
        methods
      end

      def mercado_pago_payment_available?
        business.mercado_pago_payment_enabled? && business.mercado_pago_connected?
      end

      def available_resource_for_service!
        ends_at = starts_at + service.duration_minutes.minutes
        availability = Resources::Availability.new(business:, service:, starts_at:, ends_at:)
        return unless availability.required?

        availability.first_available(lock: true) || raise(UnavailableSlot, "No hay recursos disponibles para ese horario")
      end

      def assign_professional!(customer_profile: nil)
        raise UnavailableSlot, "Ese profesional no realiza este servicio" unless employee_allowed_for_service?

        Bookings::AssignProfessionalService.call(
          business: business,
          service: service,
          starts_at: starts_at,
          preferred_professional: employee_membership,
          assignment_strategy: assignment_strategy,
          customer_profile: customer_profile,
          online_booking: source.to_s == "public_booking"
        )
      rescue Bookings::AssignProfessionalService::UnavailableProfessional => error
        raise UnavailableSlot, "El turno ya no está disponible"
      end

      def assignment_strategy
        return unless source.to_s == "public_booking"
        return Business::PUBLIC_BOOKING_ASSIGNMENT_STRATEGY_DEFAULT if business.public_booking_allow_professional_selection?

        business.public_booking_assignment_strategy
      end

      def employee_allowed_for_service?
        return true if employee_membership.blank?
        return true if service.employee_membership_ids.blank?

        service.employee_membership_ids.include?(employee_membership.id)
      end

      def slot_available_for_source?(assigned_employee)
        if source.to_s == "public_booking"
          Availability::Slots.public_available?(business:, service:, starts_at:, employee_membership: assigned_employee)
        else
          Availability::Slots.available?(business:, service:, starts_at:, employee_membership: assigned_employee)
        end
      end

      def pricing_for
        primary_price_cents = service.price_cents_for_time(starts_at, business)
        add_ons = add_on_services.map do |add_on|
          { service: add_on, price_cents: add_on.price_cents_for_time(starts_at, business) }
        end
        extras = business.extras.publicly_visible.where(id: extra_ids).map { |extra| { extra: extra, price_cents: extra.price_cents } }
        total_cents = primary_price_cents + add_ons.sum { |entry| entry.fetch(:price_cents) } + extras.sum { |entry| entry.fetch(:price_cents) }
        {
          base_price_cents: service.price_cents + add_ons.sum { |entry| entry.fetch(:service).price_cents } + extras.sum { |entry| entry.fetch(:price_cents) },
          final_price_cents: total_cents,
          discount_percentage: service.dynamic_discount_for_time(starts_at, business),
          add_ons: add_ons,
          extras: extras
        }
      end

      def add_on_services
        @add_on_services ||= begin
          allowed_ids = service.recommended_service_ids
          business.services.active.where(id: add_on_service_ids & allowed_ids).to_a
        end
      end

      def create_addons!(appointment, add_ons)
        add_ons.each do |entry|
          appointment.appointment_addons.create!(service: entry.fetch(:service), price_cents: entry.fetch(:price_cents))
        end
      end

      def create_extras!(appointment, extras)
        extras.each { |entry| appointment.appointment_extras.create!(extra: entry.fetch(:extra), price_cents: entry.fetch(:price_cents)) }
      end

      def find_or_update_customer_profile!
        Customers::UpsertProfile.call(
          business: business,
          name: customer_name,
          phone: customer_phone,
          email: customer_email
        )
      end

      def pet_for_profile(profile)
        selected_pet = if pet.present?
          pet
        elsif pet_id.present?
          profile.pets.find(pet_id)
        end

        return if selected_pet.blank? && pet_name.blank?

        Pets::Upsert.call(
          business: business,
          customer_profile: profile,
          pet: selected_pet,
          name: pet_name,
          breed: pet_breed,
          sex: pet_sex,
          birth_date: pet_birth_date,
          notes: pet_notes,
          coat_type: pet_coat_type,
          coat_details: pet_coat_details
        )
      end

      def customer_profile_for_assignment
        normalized_phone = PhoneNumber.normalize(customer_phone)
        return if normalized_phone.blank?

        business.customer_profiles.find_by(normalized_phone: normalized_phone)
      end
  end
end
