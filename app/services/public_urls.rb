class PublicUrls
  ROUTES = {
    business: [ :public_business, :custom_public_business ],
    booking: [ :new_public_booking, :new_custom_public_booking ],
    bookings: [ :public_bookings, :custom_public_bookings ],
    calendar: [ :public_booking_calendar, :custom_public_booking_calendar ],
    chat: [ :center_chat, :custom_center_chat ],
    waitlist: [ :public_waitlist_entries, :custom_public_waitlist_entries ],
    services: [ :public_services, :custom_public_services ],
    service: [ :public_service, :custom_public_service ],
    promos: [ :public_promos, :custom_public_promos ],
    category: [ :public_category, :custom_public_category ],
    category_service: [ :public_category_service, :custom_public_category_service ],
    short_service: [ :short_public_service, :custom_short_public_service ],
    customer_portal_entry: [ :customer_portal_entry, :custom_customer_portal_entry ],
    customer_portal_access: [ :customer_portal_access, :custom_customer_portal_access ],
    customer_portal_dashboard: [ :customer_portal_dashboard, :custom_customer_portal_dashboard ],
    customer_portal_dashboard_update: [ :customer_portal_dashboard_update, :custom_customer_portal_dashboard_update ],
    customer_portal_logout: [ :customer_portal_logout, :custom_customer_portal_logout ],
    customer_portal_profile_access: [ :customer_portal_profile_access, :custom_customer_portal_profile_access ],
    customer_portal_short_booking: [ :customer_portal_short_booking, :custom_customer_portal_short_booking ],
    customer_portal_booking: [ :customer_portal_booking, :custom_customer_portal_booking ],
    customer_portal_booking_reschedule_availability: [ :customer_portal_booking_reschedule_availability, :custom_customer_portal_booking_reschedule_availability ],
    customer_portal_booking_receipt: [ :customer_portal_booking_receipt, :custom_customer_portal_booking_receipt ],
    customer_portal_booking_reschedule: [ :customer_portal_booking_reschedule, :custom_customer_portal_booking_reschedule ],
    customer_portal_booking_cancel: [ :customer_portal_booking_cancel, :custom_customer_portal_booking_cancel ]
  }.freeze

  class << self
    def path(kind, business, *segments, use_custom_domain: nil, **options)
      generate(kind, business, *segments, use_custom_domain:, **options.merge(only_path: true))
    end

    def url(kind, business, *segments, use_custom_domain: nil, **options)
      generate(kind, business, *segments, use_custom_domain:, **options.merge(only_path: false))
    end

    private
      def generate(kind, business, *segments, use_custom_domain:, **options)
        kind, segments = canonical_service_route(kind, business, segments)
        platform_route, custom_route = ROUTES.fetch(kind)
        custom_domain = business&.custom_domain if business&.custom_domain_active? && use_custom_domain != false
        only_path = options.delete(:only_path)
        route_name = custom_domain.present? ? custom_route : platform_route
        route_segments = custom_domain.present? ? segments : [ business.slug, *segments ]
        route_options = options.compact

        if only_path
          route_options.except!(:host, :protocol)
          suffix = :path
        else
          suffix = :url
          route_options[:host] = custom_domain || route_options[:host] || AppUrl.host
          route_options[:protocol] = custom_domain ? AppUrl.protocol : (route_options[:protocol] || AppUrl.protocol)
        end

        route_helpers.public_send("#{route_name}_#{suffix}", *route_segments, **route_options)
      end

      def route_helpers
        Rails.application.routes.url_helpers
      end

      def canonical_service_route(kind, business, segments)
        return [ kind, segments ] unless kind == :short_service && business.present?

        service = business.services.includes(:service_category).find_by(slug: segments.first)
        category_slug = service&.service_category&.slug
        raise ArgumentError, "El servicio debe tener una categoría para generar su URL pública." if category_slug.blank?

        [ :category_service, [ category_slug, service.slug ] ]
      end
  end
end
