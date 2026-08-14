module Sales
  class TemplateRenderer
    def initialize(business:, template:, customer: nil, service: nil, booking: nil, campaign_link: nil, customer_pack: nil, gap: nil)
      @business = business
      @template = template.to_s
      @customer = customer || booking&.customer_profile
      @service = service || booking&.service
      @booking = booking
      @campaign_link = campaign_link
      @customer_pack = customer_pack
      @gap = gap
    end

    def call
      template.gsub(/\{\{([a-z_]+)\}\}/) { values.fetch(Regexp.last_match(1), "") }
    end

    private
      attr_reader :business, :template, :customer, :service, :booking, :campaign_link, :customer_pack, :gap

      def values
        @values ||= {
          "customer_name" => customer&.name.presence || booking&.customer_name.presence || "clienta",
          "business_name" => business.name,
          "service_name" => service&.name.to_s,
          "booking_date" => booking&.starts_at ? CustomerDateFormatter.date_label(booking.starts_at) : "",
          "booking_time" => booking&.starts_at ? CustomerDateFormatter.time_label(booking.starts_at) : "",
          "professional_name" => booking&.employee_membership&.name.to_s,
          "public_booking_link" => business.public_url,
          "service_link" => service_link,
          "campaign_link" => campaign_link&.tracked_url.to_s,
          "pack_name" => customer_pack&.service_pack&.name.to_s,
          "remaining_sessions" => customer_pack&.remaining_sessions.to_s,
          "gap_date" => gap_time.present? ? CustomerDateFormatter.date_label(gap_time) : "",
          "gap_time" => gap_time.present? ? CustomerDateFormatter.time_label(gap_time) : ""
        }
      end

      def service_link
        return "" if service.blank?

        PublicUrls.url(
          :booking,
          business,
          service_id: service.slug,
          date: Time.zone.today,
          host: app_host,
          protocol: app_protocol
        )
      end

      def gap_time
        gap&.respond_to?(:starts_at) ? gap.starts_at : nil
      end

      def app_host
        business.custom_domain_active? ? business.custom_domain : AppUrl.host
      end

      def app_protocol
        AppUrl.protocol
      end
  end
end
