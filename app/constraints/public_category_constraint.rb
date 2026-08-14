class PublicCategoryConstraint
  def initialize(custom_domain:)
    @custom_domain = custom_domain
  end

  def matches?(request)
    business, category_slug = business_and_category_slug_for(request)
    return false unless business&.full_website_mode? && category_slug.present?

    business.service_categories.active
      .where(slug: category_slug)
      .joins(:services)
      .merge(Service.publicly_bookable)
      .exists?
  end

  private
    attr_reader :custom_domain

    def business_and_category_slug_for(request)
      parts = request.path.split("/").reject(&:blank?)
      if custom_domain
        [ Business.find_by_custom_domain(request.host), parts.first ]
      else
        [ Business.find_by(slug: parts.first), parts.second ]
      end
    end
end
