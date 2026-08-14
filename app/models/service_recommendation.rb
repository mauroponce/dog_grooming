class ServiceRecommendation < ApplicationRecord
  belongs_to :service, touch: true
  belongs_to :recommended_service, class_name: "Service"

  validates :recommended_service_id, uniqueness: { scope: :service_id }
  validate :same_business
  validate :not_self
  after_commit :broadcast_public_services_later, on: %i[create update destroy]

  private
    def same_business
      return if service.blank? || recommended_service.blank? || service.business_id == recommended_service.business_id

      errors.add(:recommended_service, "debe pertenecer al mismo negocio")
    end

    def not_self
      return if service.blank? || recommended_service.blank? || service_id != recommended_service_id

      errors.add(:recommended_service, "no puede ser el mismo servicio")
    end

    def broadcast_public_services_later
      PublicBooking::BroadcastServicesJob.perform_later(service.business_id)
    end
end
