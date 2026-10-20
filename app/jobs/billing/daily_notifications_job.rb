module Billing
  class DailyNotificationsJob < ApplicationJob
    queue_as :default

    def perform
      Billing::DailyProcessor.call
      Billing::DailyNotifications.call
    end
  end
end
