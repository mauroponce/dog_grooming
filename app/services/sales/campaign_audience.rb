module Sales
  class CampaignAudience
    def initialize(business:, objective:, service: nil, limit: 30)
      @business = business
      @objective = objective.to_s
      @service = service
      @limit = limit
    end

    def call
      relation.distinct.limit(limit)
    end

    private
      attr_reader :business, :objective, :service, :limit

      def relation
        case objective
        when "reactivate_customers"
          inactive_customers
        when "promote_service", "sell_pack"
          customers_for_service
        when "waitlist_offer"
          waitlist_customers
        else
          business.customer_profiles.order(updated_at: :desc)
        end
      end

      def inactive_customers
        ids = business.appointments.completed.where.not(customer_profile_id: nil).group(:customer_profile_id).maximum(:starts_at).select do |_id, last_at|
          last_at <= 60.days.ago
        end.keys
        business.customer_profiles.where(id: ids)
      end

      def customers_for_service
        return business.customer_profiles.none if service.blank?

        ids = business.appointments.where(service: service).where.not(customer_profile_id: nil).distinct.select(:customer_profile_id)
        business.customer_profiles.where(id: ids)
      end

      def waitlist_customers
        ids = business.waitlist_entries.visible.where.not(customer_profile_id: nil).distinct.select(:customer_profile_id)
        business.customer_profiles.where(id: ids)
      end
  end
end
