module Resources
  class Availability
    def initialize(business:, service:, starts_at:, ends_at: nil, excluding_appointment: nil)
      @business = business
      @service = service
      @starts_at = starts_at
      @ends_at = ends_at || starts_at + service.duration_minutes.minutes
      @excluding_appointment = excluding_appointment
    end

    def required?
      requirements.any?
    end

    def any_available?(lock: false)
      return true unless required?

      first_available(lock:) != nil
    end

    def first_available(lock: false)
      return unless required?

      resources = bookable_resources(lock:)
      resources.find { |resource| available?(resource) }
    end

    def available?(resource)
      return false unless resource&.available_for_booking?

      required_quantity = required_quantity_for(resource)
      return false unless required_quantity.positive?

      available_quantity(resource) >= required_quantity
    end

    def available_quantity(resource)
      [ resource.quantity.to_i - occupied_quantity(resource) - blocked_quantity(resource), 0 ].max
    end

    def occupied_quantity(resource)
      overlapping_appointments(resource).sum do |appointment|
        quantity_required_for_service(resource, appointment.service)
      end
    end

    def blocked?(resource)
      manual_blocked?(resource) || availability_blocked?(resource)
    end

    def blocked_quantity(resource)
      blocked?(resource) ? resource.quantity.to_i : 0
    end

    def required_quantity_for(resource)
      quantity_required_for_service(resource, service)
    end

    private
      attr_reader :business, :service, :starts_at, :ends_at, :excluding_appointment

      def bookable_resources(lock:)
        if service.association(:service_resources).loaded? && !lock
          return requirements
            .map(&:bookable_resource)
            .compact
            .select { |resource| resource.archived_at.blank? }
            .sort_by(&:name)
        end

        relation = service.bookable_resources.visible.order(:name)
        relation = relation.lock if lock
        relation.to_a
      end

      def requirements
        @requirements ||= if service.association(:service_resources).loaded?
          service.service_resources.to_a
        else
          service.service_resources.includes(:bookable_resource).to_a
        end
      end

      def quantity_required_for_service(resource, candidate_service)
        requirement = requirement_lookup(candidate_service)[resource.id]
        requirement&.quantity_required.to_i.presence || 1
      end

      def requirement_lookup(candidate_service)
        @requirement_lookup ||= {}
        @requirement_lookup[candidate_service.id] ||= candidate_service.service_resources.index_by(&:bookable_resource_id)
      end

      def overlapping_appointments(resource)
        relation = business.appointments.active
          .includes(:service)
          .where(bookable_resource_id: resource.id)
          .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)

        relation = relation.where.not(id: excluding_appointment.id) if excluding_appointment&.persisted?
        relation
      end

      def manual_blocked?(resource)
        business.resource_blocks.active
          .where(bookable_resource_id: resource.id)
          .overlapping(starts_at, ends_at)
          .exists?
      end

      def availability_blocked?(resource)
        AvailabilityBlock.blocking_time?(
          business: business,
          starts_at: starts_at,
          ends_at: ends_at,
          bookable_resource: resource
        )
      end
  end
end
