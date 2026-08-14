module BookingIntents
  class ExpireJob < ApplicationJob
    queue_as :default

    def perform(business_id = nil)
      business = Business.find_by(id: business_id) if business_id.present?
      BookingIntents::ExpireService.call(business:)
    end
  end
end
