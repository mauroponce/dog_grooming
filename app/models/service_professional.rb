class ServiceProfessional < ApplicationRecord
  belongs_to :service, touch: true
  belongs_to :employee_membership

  validates :employee_membership_id, uniqueness: { scope: :service_id }
  validate :same_business
  after_commit :broadcast_public_services_later, on: %i[create update destroy]

  private
    def same_business
      return if service.blank? || employee_membership.blank? || service.business_id == employee_membership.business_id

      errors.add(:employee_membership, "debe pertenecer al mismo negocio")
    end

    def broadcast_public_services_later
      PublicBooking::BroadcastServicesJob.perform_later(service.business_id)
    end
end
