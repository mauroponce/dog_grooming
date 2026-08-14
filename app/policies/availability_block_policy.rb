class AvailabilityBlockPolicy < ApplicationPolicy
  def create?
    owner_admin? || employee_can?("can_manage_availability")
  end

  def destroy?
    owner_admin? || employee_can_manage_record?
  end

  private
    def employee_can_manage_record?
      membership = user&.employee_membership_for(business)
      return false unless membership&.can?("can_manage_availability")
      return true if membership.can?("can_view_all_bookings")

      record.respond_to?(:employee_membership_id) && record.employee_membership_id == membership.id
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        business = user.primary_business
        relation = scope.where(business: business)
        return relation if user.admin? || user.super_admin?

        membership = user.employee_membership_for(business)
        return scope.none unless membership&.can?("can_manage_availability")
        return relation if membership.can?("can_view_all_bookings")

        relation.where(employee_membership_id: [ nil, membership.id ])
      end
    end
end
