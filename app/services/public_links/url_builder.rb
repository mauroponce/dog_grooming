module PublicLinks
  class UrlBuilder
    def self.business(business, **params)
      PublicUrls.url(:business, business, **params.merge(host: host, protocol: protocol))
    end

    def self.service(service, **params)
      PublicUrls.url(:short_service, service.business, service.slug, **params.merge(host: host, protocol: protocol))
    end

    def self.host
      AppUrl.host
    end

    def self.protocol
      AppUrl.protocol
    end
  end
end
