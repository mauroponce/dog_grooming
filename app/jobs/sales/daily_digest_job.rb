module Sales
  class DailyDigestJob < ApplicationJob
    queue_as :default

    def perform(business_id = nil)
      scope = business_id.present? ? Business.where(id: business_id) : Business.where(disabled_at: nil, email_daily_sales_digest: true)
      scope.find_each do |business|
        Sales::GenerateOpportunities.call(business: business)
        SalesMailer.daily_sales_digest(business).deliver_later if business.owner.email_address.present?
      end
    end
  end
end
