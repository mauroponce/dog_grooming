class CampaignLinksController < ApplicationController
  allow_unauthenticated_access

  def show
    link = CampaignLink.active.includes(:business).find_by!(slug: params[:slug])
    Sales::TrackVisit.new(controller: self, business: link.business, campaign_link: link).call
    redirect_to link.destination_url, allow_other_host: true
  end
end
