class BookingAttribution < ApplicationRecord
  belongs_to :business
  belongs_to :appointment
  belongs_to :campaign_link, optional: true

  validates :appointment_id, uniqueness: true
  validate :records_belong_to_business

  private
    def records_belong_to_business
      errors.add(:appointment, "no pertenece al negocio") if appointment.present? && appointment.business_id != business_id
      errors.add(:campaign_link, "no pertenece al negocio") if campaign_link.present? && campaign_link.business_id != business_id
    end
end
