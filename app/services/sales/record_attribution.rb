module Sales
  class RecordAttribution
    def initialize(appointment:, attribution:)
      @appointment = appointment
      @attribution = (attribution || {}).to_h
    end

    def call
      return if attribution.blank?

      appointment.create_booking_attribution!(
        business: appointment.business,
        campaign_link: campaign_link,
        source: attribution["source"],
        medium: attribution["medium"],
        campaign: attribution["campaign"],
        landing_url: attribution["landing_url"],
        metadata: attribution.except("campaign_link_id", "source", "medium", "campaign", "landing_url")
      )
    end

    private
      attr_reader :appointment, :attribution

      def campaign_link
        return if attribution["campaign_link_id"].blank?

        appointment.business.campaign_links.find_by(id: attribution["campaign_link_id"])
      end
  end
end
