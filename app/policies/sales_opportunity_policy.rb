class SalesOpportunityPolicy < ApplicationPolicy
  def index?
    owner_admin?
  end

  def update?
    owner_admin?
  end

  def mark_contacted?
    update?
  end

  def dismiss?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      business = user.primary_business
      return scope.none if business.blank?

      relation = scope.where(business: business)
      return relation if user.admin? || user.super_admin?

      scope.none
    end
  end
end
