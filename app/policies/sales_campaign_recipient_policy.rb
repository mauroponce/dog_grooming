class SalesCampaignRecipientPolicy < ApplicationPolicy
  def mark_contacted?
    owner_admin?
  end

  def dismiss?
    owner_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      business = user.primary_business
      return scope.none if business.blank?

      return scope.where(business: business) if user.admin? || user.super_admin?

      scope.none
    end
  end
end
