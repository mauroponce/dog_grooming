module Bookings
  class ServiceSelection < SimpleDelegator
    attr_reader :service, :variant

    def initialize(service:, variant: nil)
      @service = service
      @variant = variant
      super(service)
    end

    def duration_minutes
      variant&.duration_minutes || service.duration_minutes
    end

    def price_cents
      variant&.price_cents || service.price_cents
    end

    def price_cents_for_time(datetime, center = service.business)
      price_cents
    end

    def expected_deposit_amount_cents
      service.deposit_amount_cents_for(price_cents)
    end
  end
end
