class ServiceFormPolicy < ApplicationPolicy
  def index?
    owner_admin? || employee_can_any?("can_manage_service_forms", "can_manage_services")
  end

  def create?
    index?
  end

  def update?
    index?
  end

  def destroy?
    index?
  end

  class Scope < Scope
    def resolve
      business = user&.primary_business
      business.present? ? scope.where(business:) : scope.none
    end
  end
end
