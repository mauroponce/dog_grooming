module Sales
  class ExpireOldOpportunitiesJob < ApplicationJob
    queue_as :default

    def perform
      SalesOpportunity.open.where("created_at < ?", 30.days.ago).update_all(status: "expired", updated_at: Time.current)
      SalesOpportunity.open.where(opportunity_type: %w[fillable_gap waitlist_match]).where("due_at < ?", Time.current).update_all(status: "expired", updated_at: Time.current)
    end
  end
end
