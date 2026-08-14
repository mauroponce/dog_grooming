module Sales
  class GenerateOpportunitiesJob < ApplicationJob
    queue_as :default

    def perform(business_id = nil)
      scope = business_id.present? ? Business.where(id: business_id) : Business.where(disabled_at: nil)
      scope.find_each { |business| Sales::GenerateOpportunities.call(business: business) }
    end
  end
end
