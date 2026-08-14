class WaitlistEntryPolicy < ApplicationPolicy
  def dismiss?
    owner_admin? || employee_can?("can_edit_bookings")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      business = user.primary_business
      return scope.none if business.blank?

      scope.where(center: business)
    end
  end
end
