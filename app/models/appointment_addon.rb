class AppointmentAddon < ApplicationRecord
  belongs_to :appointment
  belongs_to :service

  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :service_belongs_to_appointment_business

  private
    def service_belongs_to_appointment_business
      return if appointment.blank? || service.blank? || appointment.business_id == service.business_id

      errors.add(:service, "no pertenece al negocio del turno")
    end
end
