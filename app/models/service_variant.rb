class ServiceVariant < ApplicationRecord
  belongs_to :service
  belongs_to :pet_size_band

  validates :pet_size_band_id, uniqueness: { scope: :service_id }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :duration_minutes, inclusion: { in: Service::DURATIONS }
  validate :records_belong_to_same_business

  scope :active, -> { where(active: true) }
  scope :ordered, -> { joins(:pet_size_band).order("pet_size_bands.position") }

  def display_name
    "#{pet_size_band.name} · #{pet_size_band.weight_label}"
  end

  def price
    price_cents.to_i / 100.0
  end

  def price=(value)
    self.price_cents = (BigDecimal(value.to_s.presence || "0") * 100).to_i
  end

  private
    def records_belong_to_same_business
      return if service.blank? || pet_size_band.blank? || service.business_id == pet_size_band.business_id

      errors.add(:pet_size_band, "no pertenece a esta peluquería")
    end
end
