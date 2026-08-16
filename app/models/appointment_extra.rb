class AppointmentExtra < ApplicationRecord
  belongs_to :appointment
  belongs_to :extra

  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :extra_id, uniqueness: { scope: :appointment_id }
end
