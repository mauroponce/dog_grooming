class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  private
    def super_admin?
      user&.super_admin?
    end

    def owner_admin?
      (user&.admin? || user&.super_admin?) && business.present? && user.business&.id == business.id
    end

    def employee_can?(permission)
      return false unless user&.employee? && business.present?

      user.employee_membership_for(business)&.can?(permission)
    end

    def employee_can_any?(*permissions)
      permissions.any? { |permission| employee_can?(permission) }
    end

    def business
      if record.is_a?(Business)
        record
      elsif record.respond_to?(:business)
        record.business
      elsif record.respond_to?(:center)
        record.center
      end
    end

    class Scope
      def initialize(user, scope)
        @user = user
        @scope = scope
      end

      def resolve
        raise NoMethodError, "You must define #resolve in #{self.class}"
      end

      private
        attr_reader :user, :scope
    end
end
