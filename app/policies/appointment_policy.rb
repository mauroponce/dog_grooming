class AppointmentPolicy < ApplicationPolicy
  def create?
    owner_admin? || employee_can?("can_create_bookings")
  end

  def update?
    owner_admin? || employee_can_edit_record?
  end

  def confirm?
    return review_deposit? if record.deposit_required? && record.deposit_status != "approved"

    update?
  end

  def cancel?
    owner_admin? || employee_can_cancel_record?
  end

  def destroy?
    record.manual? && (owner_admin? || employee_can_manage_manual_record?)
  end

  def finalize?
    owner_admin? || employee_can_finalize_record?
  end

  def review_deposit?
    return true if owner_admin?

    membership = user&.employee_membership_for(business)
    return false unless membership&.can?("can_approve_deposits") || membership&.can?("can_reject_deposits")
    return true if membership.can?("can_view_all_bookings")

    record.respond_to?(:employee_membership_id) && record.employee_membership_id == membership.id
  end

  def approve_deposit?
    deposit_permission_for?("can_approve_deposits")
  end

  def reject_deposit?
    deposit_permission_for?("can_reject_deposits")
  end

  private
    def employee_can_edit_record?
      membership = user&.employee_membership_for(business)
      return false unless membership&.can?("can_edit_bookings")
      return true if membership.can?("can_view_all_bookings")

      record.respond_to?(:employee_membership_id) && record.employee_membership_id == membership.id
    end

    def employee_can_manage_manual_record?
      membership = user&.employee_membership_for(business)
      return false unless membership&.can?("can_create_bookings") || membership&.can?("can_edit_bookings")
      return true if membership.can?("can_view_all_bookings")

      record.respond_to?(:employee_membership_id) && record.employee_membership_id == membership.id
    end

    def employee_can_cancel_record?
      membership = user&.employee_membership_for(business)
      return false unless membership&.can?("can_cancel_bookings")
      return true if membership.can?("can_view_all_bookings")

      record.respond_to?(:employee_membership_id) && record.employee_membership_id == membership.id
    end

    def employee_can_finalize_record?
      membership = user&.employee_membership_for(business)
      return false unless membership&.can?("can_edit_internal_notes")
      return true if membership.can?("can_complete_all_bookings") || membership.can?("can_view_all_bookings")
      return false unless membership.can?("can_complete_own_bookings") || membership.can?("can_edit_bookings")

      record.respond_to?(:employee_membership_id) && record.employee_membership_id == membership.id
    end

    def deposit_permission_for?(permission)
      return true if owner_admin?

      membership = user&.employee_membership_for(business)
      return false unless membership&.can?(permission)
      return true if membership.can?("can_view_all_bookings")

      record.respond_to?(:employee_membership_id) && record.employee_membership_id == membership.id
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        business = user.primary_business
        relation = scope.where(business: business)
        return relation if user.admin? || user.super_admin?

        membership = user.employee_membership_for(business)
        return scope.none unless membership&.can?("can_create_bookings") ||
          membership&.can?("can_edit_bookings") ||
          membership&.can?("can_view_all_bookings") ||
          membership&.can?("can_approve_deposits") ||
          membership&.can?("can_reject_deposits")
        return relation if membership.can?("can_view_all_bookings")

        relation.where(employee_membership_id: membership.id)
      end
    end
end
