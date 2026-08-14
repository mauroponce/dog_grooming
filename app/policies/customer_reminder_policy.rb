class CustomerReminderPolicy < ApplicationPolicy
  def create?
    owner_admin? || employee_can?("can_edit_internal_notes")
  end

  def resolve?
    owner_admin? || employee_can?("can_edit_internal_notes")
  end

  def dismiss?
    resolve?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      business = user.primary_business
      return scope.none if business.blank?

      relation = scope.where(business: business)
      return relation if user.admin? || user.super_admin?

      membership = user.employee_membership_for(business)
      return scope.none unless membership
      return relation if membership.can?("can_view_all_customers")

      relation.where(assigned_to: user)
    end
  end
end
