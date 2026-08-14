class PackSession < ApplicationRecord
  belongs_to :business
  belongs_to :customer_pack
  belongs_to :appointment, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :used_at, presence: true
  validates :appointment_id, uniqueness: { scope: :customer_pack_id }, allow_nil: true
  validate :records_belong_to_business

  private
    def records_belong_to_business
      errors.add(:customer_pack, "no pertenece al negocio") if customer_pack.present? && customer_pack.business_id != business_id
      errors.add(:appointment, "no pertenece al negocio") if appointment.present? && appointment.business_id != business_id
    end
end
