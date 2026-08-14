class ServiceResource < ApplicationRecord
  belongs_to :service, touch: true
  belongs_to :bookable_resource

  validates :bookable_resource_id, uniqueness: { scope: :service_id }
  validates :quantity_required, numericality: { only_integer: true, greater_than: 0 }
  validate :same_business
  after_commit :broadcast_public_services_later, on: %i[create update destroy]

  private
    def same_business
      return if service.blank? || bookable_resource.blank? || service.business_id == bookable_resource.business_id

      errors.add(:bookable_resource, "debe pertenecer al mismo negocio")
    end

    def broadcast_public_services_later
      PublicBooking::BroadcastServicesJob.perform_later(service.business_id)
    end
end
