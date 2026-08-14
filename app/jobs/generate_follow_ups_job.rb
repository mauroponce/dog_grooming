class GenerateFollowUpsJob < ApplicationJob
  queue_as :default

  def perform(business_id = nil, send_digest: false)
    businesses = business_id.present? ? Business.where(id: business_id) : Business.where(disabled_at: nil)
    businesses.find_each do |business|
      reminders = FollowUps::GenerateService.call(business: business)
      BusinessMailer.follow_up_digest(business, reminders).deliver_later if send_digest && reminders.any? && business.email_daily_digest?
    end
  end
end
