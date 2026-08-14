class ServiceCatalogItem < ApplicationRecord
  belongs_to :service_catalog_category

  validates :name, :service_category, :description, presence: true
  validates :duration_minutes, inclusion: { in: Service::DURATIONS }
  validates :price_cents, :deposit_amount_cents, :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  normalizes :name, :service_category, :description, with: ->(value) { value.to_s.strip.presence }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :name) }

  def service_template
    {
      name: name,
      category: service_category,
      description: description,
      duration_minutes: duration_minutes,
      price: price_cents.to_i / 100
    }
  end
end
