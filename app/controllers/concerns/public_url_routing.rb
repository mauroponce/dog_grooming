module PublicUrlRouting
  ROUTE_SEGMENTS = {
    business: [],
    booking: [],
    bookings: [],
    calendar: [],
    services: [],
    service: [ :service_slug ],
    category: [ :category_slug ],
    category_service: [ :category_slug, :service_slug ],
    short_service: [ :service_slug ]
  }.freeze

  PublicUrls::ROUTES.each_key do |kind|
    define_method("#{PublicUrls::ROUTES.fetch(kind).first}_path") do |*args, **kwargs|
      public_route_destination(kind, :path, args, kwargs)
    end

    define_method("#{PublicUrls::ROUTES.fetch(kind).first}_url") do |*args, **kwargs|
      public_route_destination(kind, :url, args, kwargs)
    end
  end

  private
    def public_route_destination(kind, output, args, kwargs)
      arguments = args.dup
      options = arguments.last.is_a?(Hash) ? arguments.pop.to_h.symbolize_keys : {}
      options.merge!(kwargs)
      slug = options.delete(:slug) || arguments.shift
      segments = ROUTE_SEGMENTS.fetch(kind).map { |key| options.delete(key) || arguments.shift }

      business = public_route_business(slug)
      use_custom_path = custom_domain_request_for?(business)

      if kind == :short_service && business.present?
        return PublicUrls.public_send(
          output,
          kind,
          business,
          *segments,
          **options.merge(use_custom_domain: use_custom_path)
        )
      end

      unless use_custom_path
        route_name = PublicUrls::ROUTES.fetch(kind).first
        return Rails.application.routes.url_helpers.public_send(
          "#{route_name}_#{output}",
          slug,
          *segments,
          **options
        )
      end

      PublicUrls.public_send(output, kind, business, *segments, **options)
    end

    def public_route_business(slug)
      return @business if defined?(@business) && @business&.slug == slug.to_s

      Business.find_by(slug: slug)
    end

    def custom_domain_request_for?(business)
      business.present? && business.custom_domain_active? &&
        Business.normalize_custom_domain(request.host) == business.custom_domain
    end
end
