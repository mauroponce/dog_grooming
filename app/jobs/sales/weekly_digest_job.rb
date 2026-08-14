module Sales
  class WeeklyDigestJob < ApplicationJob
    queue_as :default

    def perform(business_id = nil)
      scope = business_id.present? ? Business.where(id: business_id) : Business.where(disabled_at: nil, email_weekly_sales_digest: true)
      scope.find_each { |business| SalesMailer.weekly_sales_digest(business).deliver_later if business.owner.email_address.present? }
    end
  end
end
