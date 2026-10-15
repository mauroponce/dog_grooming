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
        business.subscription&.plan_details&.fetch(:amount_cents) || Subscription::PLANS.fetch("basic").fetch(:amount_cents)
      end

      def active_professionals_count
        business.employee_memberships.available_for_booking.count
      end
  end
end
