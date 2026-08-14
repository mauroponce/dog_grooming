class CampaignVisit < ApplicationRecord
  belongs_to :business
  belongs_to :campaign_link, optional: true

  validates :visited_at, presence: true
  validate :link_belongs_to_business

  private
    def link_belongs_to_business
      return if campaign_link.blank? || business.blank? || campaign_link.business_id == business_id

      errors.add(:campaign_link, "no pertenece al negocio")
    end
end
