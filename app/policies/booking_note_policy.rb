class BookingNotePolicy < ApplicationPolicy
  def show?
    owner_admin? || employee_can_view_customer_history?
  end

  def create?
    owner_admin? || employee_can?("can_edit_internal_notes")
  end

  private
    def employee_can_view_customer_history?
      membership = user&.employee_membership_for(business)
      return false unless membership&.can?("can_view_customer_history") || membership&.can?("can_edit_internal_notes") || membership&.can?("can_view_all_customers")
      return true if membership.can?("can_view_all_customers")

      record.appointment.employee_membership_id == membership.id
    end
end
