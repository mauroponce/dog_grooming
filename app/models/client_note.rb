class ClientNote < ApplicationRecord
  belongs_to :business
  belongs_to :customer_profile
  belongs_to :user, optional: true

  validates :body, :note_type, presence: true
  validate :customer_belongs_to_business

  private
    def customer_belongs_to_business
      return if customer_profile.blank? || business.blank? || customer_profile.business_id == business_id

      errors.add(:customer_profile, "no pertenece a este negocio")
    end
end
