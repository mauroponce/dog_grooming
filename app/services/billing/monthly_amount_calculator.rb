module Billing
  class MonthlyAmountCalculator
    Result = Struct.new(
      :base_amount_cents,
      :active_professionals_count,
      :total_amount_cents,
      keyword_init: true
    )

    def self.call(business)
      new(business).call
    end

    def initialize(business)
      @business = business
    end

    def call
      Result.new(
        base_amount_cents: base_amount_cents,
        active_professionals_count: active_professionals_count,
        total_amount_cents: base_amount_cents
      )
    end

    private
      attr_reader :business

      def base_amount_cents
        return business.subscription.amount_cents if business.subscription&.mercado_pago? && business.subscription.provider_subscription_id.present?
        return PlatformMercadoPagoAccount.current.monthly_amount_cents if business.subscription&.mercado_pago?

        Business::SUBSCRIPTION_DETAILS.fetch(:monthly_amount_cents)
      end

      def active_professionals_count
        business.employee_memberships.available_for_booking.count
      end
  end
end
