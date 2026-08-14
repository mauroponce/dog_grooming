class WhatsAppTemplatePolicy < ApplicationPolicy
  def index?
    owner_admin?
  end

  def update?
    owner_admin?
  end

  def restore_default?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      business = user.primary_business
      return scope.none if business.blank?

      scope.where(business: business)
    end
  end
end
