class SalesCampaignRecipientPolicy < ApplicationPolicy
  def open_whatsapp?
    owner_admin?
  end

  def mark_contacted?
    open_whatsapp?
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
