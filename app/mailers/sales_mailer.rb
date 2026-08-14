class SalesMailer < ApplicationMailer
  def daily_sales_digest(business)
    @business = business
    @opportunities = business.sales_opportunities.open.recent.limit(8)
    @gaps = Availability::FillableGaps.new(business: business, date: Time.zone.today).call.first(5)
    @url = admin_calendar_url(host: app_host, protocol: app_protocol)

    mail subject: "Oportunidades para llenar más turnos hoy", to: business.owner.email_address
  end

  def weekly_sales_digest(business)
    @business = business
    range = 1.week.ago..Time.current
    @campaigns_count = business.sales_campaigns.where(created_at: range).count
    @contacted_count = business.sales_opportunities.where(status: "contacted", updated_at: range).count
    @attributed_bookings_count = business.booking_attributions.where(created_at: range).count
    @top_links = business.campaign_links.includes(:booking_attributions, :campaign_visits).recent.limit(5)
    @url = admin_calendar_url(host: app_host, protocol: app_protocol)

    mail subject: "Resumen semanal de ventas en Dog Grooming", to: business.owner.email_address
  end

  def campaign_summary(campaign)
    @campaign = campaign
    @business = campaign.business
    @url = admin_calendar_url(host: app_host, protocol: app_protocol)

    mail subject: "Campaña lista para contactar clientas", to: @business.owner.email_address
  end
end
