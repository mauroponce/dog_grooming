class SendBusinessDailyDigestJob < ApplicationJob
  queue_as :default

  def perform(business_id = nil)
    scope = business_id.present? ? Business.where(id: business_id) : daily_notification_scope
    scope.find_each do |business|
      FollowUps::GenerateService.call(business: business)
      BusinessMailer.daily_digest(business).deliver_later if business.email_daily_digest?
    end
  end

  private
    def daily_notification_scope
      Business
        .where(disabled_at: nil)
        .where(email_daily_digest: true)
    end
end
