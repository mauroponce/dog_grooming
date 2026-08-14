module Billing
  class DailyJob < ApplicationJob
    queue_as :default

    def perform
      Billing::DailyProcessor.call
    end
  end
end
