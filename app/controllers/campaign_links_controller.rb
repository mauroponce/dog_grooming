class CampaignLinksController < ApplicationController
  allow_unauthenticated_access

  def show
    link = CampaignLink.active.includes(:business).find_by!(slug: params[:slug])
    Sales::TrackVisit.new(controller: self, business: link.business, campaign_link: link).call
    destination = URI.parse(link.destination_url)
    redirect_to destination.request_uri
  end
end
