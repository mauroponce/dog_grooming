class CustomDomainConstraint
  def matches?(request)
    Business.find_by_custom_domain(request.host).present?
  end
end
