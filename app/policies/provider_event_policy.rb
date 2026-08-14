class ProviderEventPolicy < ApplicationPolicy
  def index?
    mark_read?
  end

  def open?
    mark_read?
  end

  def mark_read?
    owner_admin? || employee_can_any?("can_view_all_bookings", "can_create_bookings", "can_edit_bookings")
  end

  def destroy?
    mark_read?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      business = user.primary_business
      return scope.none if business.blank?

      scope.where(business: business)
    end
  end
end
