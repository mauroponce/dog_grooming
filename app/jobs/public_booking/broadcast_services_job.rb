module PublicBooking
  class BroadcastServicesJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(business_id)
      business = Business.find(business_id)
      services = business.services.publicly_bookable.includes(:service_tags).order(:category, :sort_order, :name).to_a
      categories = services.map(&:category_label).uniq

      Turbo::StreamsChannel.broadcast_replace_to(
        *LiveStreams.public_services(business),
        target: ActionView::RecordIdentifier.dom_id(business, :public_services),
        partial: "public_booking/service_selection",
        locals: { business: business, services: services, categories: categories }
      )
    end
  end
end
