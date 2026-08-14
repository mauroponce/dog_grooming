class SendBusinessWeeklyDigestJob < ApplicationJob
  queue_as :default

  def perform(business_id = nil)
    scope = business_id.present? ? Business.where(id: business_id) : Business.where(disabled_at: nil, email_weekly_digest: true)
    scope.find_each { |business| BusinessMailer.weekly_digest(business).deliver_later }
  end
end
