class BusinessPolicy < ApplicationPolicy
  def dashboard?
    appointments?
  end

  def analytics?
    owner_admin?
  end

  def sales?
    owner_admin?
  end

  def service_forms?
    owner_admin? || employee_can_any?("can_manage_service_forms", "can_manage_services")
  end

  def appointments? = owner_admin? || active_employee?

  def waitlist? = false

  def deposit_proofs?
    owner_admin? || employee_can_any?("can_approve_deposits", "can_reject_deposits")
  end

  def services? = owner_admin?

  def resources?
    owner_admin? || employee_can?("can_manage_resources")
  end

  def pricing?
    owner_admin?
  end

  def availability? = owner_admin?

  def customers? = owner_admin? || active_employee?

  def settings?
    owner_admin?
  end

  def tutorials?
    owner_admin?
  end

  def billing?
    owner_admin? && record.billing_enabled?
  end

  def branches?
    owner_admin?
  end

  def employees?
    owner_admin?
  end

  private

    def active_employee?
      user&.employee? && user.employee_membership_for(record)&.active?
    end
end
