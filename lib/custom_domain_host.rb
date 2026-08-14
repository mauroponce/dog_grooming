class CustomDomainHost
  def ===(host)
    Business.find_by_custom_domain(host).present?
  rescue ActiveRecord::ActiveRecordError
    false
  end
end
