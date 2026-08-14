class BusinessPolicy < ApplicationPolicy
  def dashboard?
    owner_admin? || employee_can_any?(
      "can_view_all_bookings",
      "can_create_bookings",
      "can_edit_bookings",
      "can_approve_deposits",
      "can_reject_deposits",
      "can_view_all_customers",
      "can_view_customer_history",
      "can_manage_services",
      "can_manage_availability",
      "can_manage_resources",
      "can_manage_public_presence",
      "can_manage_service_forms"
    )
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

  def appointments?
    owner_admin? || employee_can_any?("can_view_all_bookings", "can_create_bookings", "can_edit_bookings")
  end

  def waitlist?
    owner_admin? || employee_can_any?("can_view_all_bookings", "can_edit_bookings", "can_manage_services")
  end

  def deposit_proofs?
    owner_admin? || employee_can_any?("can_approve_deposits", "can_reject_deposits")
  end

  def services?
    owner_admin? || employee_can?("can_manage_services")
  end

  def resources?
    owner_admin? || employee_can?("can_manage_resources")
  end

  def pricing?
    owner_admin?
  end

  def availability?
    owner_admin? || employee_can?("can_manage_availability")
  end

  def customers?
    owner_admin? || employee_can_any?("can_view_all_customers", "can_view_customer_history", "can_edit_customers", "can_edit_internal_notes", "can_create_bookings", "can_edit_bookings")
  end

  def settings?
    owner_admin?
  end

  def tutorials?
    owner_admin?
  end

  def whatsapp_templates?
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
end
