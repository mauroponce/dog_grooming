class CustomerPackPolicy < ApplicationPolicy
  def create?
    owner_admin?
  end

  def consume?
    create?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      business = user.primary_business
      return scope.none if business.blank?

      return scope.where(business: business) if user.admin? || user.super_admin?

      scope.none
    end
  end
end
