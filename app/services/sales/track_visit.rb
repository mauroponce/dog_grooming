require "digest"

module Sales
  class TrackVisit
    def initialize(controller:, business:, campaign_link: nil)
      @controller = controller
      @business = business
      @campaign_link = campaign_link
    end

    def call
      attribution = attribution_payload
      return if attribution.blank?

      controller.session[:sales_attribution] = attribution
      record_visit!(attribution)
    end

    private
      attr_reader :controller, :business, :campaign_link

      def attribution_payload
        link = campaign_link || business.campaign_links.active.find_by(slug: controller.params[:clid])
        source = controller.params[:src].presence || link&.source
        return if source.blank? && link.blank?

        {
          "campaign_link_id" => link&.id,
          "source" => source,
          "medium" => controller.params[:medium].presence || link&.medium,
          "campaign" => controller.params[:campaign].presence || link&.campaign,
          "landing_url" => controller.request.original_url,
          "recorded_at" => Time.current.iso8601
        }.compact
      end

      def record_visit!(payload)
        visitor_token = cookies.signed[:visitor_token].presence || SecureRandom.hex(16)
        cookies.permanent.signed[:visitor_token] = visitor_token

        business.campaign_visits.create!(
          campaign_link_id: payload["campaign_link_id"],
          session_id: session_identifier,
          visitor_token: visitor_token,
          ip_hash: Digest::SHA256.hexdigest("#{controller.request.remote_ip}-#{Rails.application.secret_key_base}"),
          user_agent: controller.request.user_agent.to_s.first(500),
          referer: controller.request.referer.to_s.first(500),
          visited_at: Time.current
        )
      end

      def session_identifier
        value = controller.session.id
        value.respond_to?(:public_id) ? value.public_id.to_s : value.to_s
      end

      def cookies
        controller.send(:cookies)
      end
  end
end
