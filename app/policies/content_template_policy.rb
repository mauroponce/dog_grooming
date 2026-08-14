class ContentTemplatePolicy < ApplicationPolicy
  def index?
    owner_admin?
  end

  def update?
    index?
  end

  class Scope < Scope
    def resolve
      business = user&.primary_business
      return scope.none if business.blank?
      return scope.where(business:) if user.admin? || user.super_admin?

      scope.none
    end
  end
end
