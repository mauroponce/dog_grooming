class ServiceCatalogCategory < ApplicationRecord
  DEFAULT_KEY = "bano_y_secado"

  has_many :service_catalog_items, dependent: :destroy
  has_many :businesses, dependent: :nullify

  validates :key, :name, :business_industry, presence: true
  validates :key, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  normalizes :key, :name, :description, :business_industry, with: ->(value) { value.to_s.strip.presence }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :name) }

  def self.default
    active.find_by(key: DEFAULT_KEY) || active.ordered.first
  end

  def signup_value
    "#{business_industry}:#{key}"
  end

  def service_templates
    service_catalog_items.active.ordered.map(&:service_template)
  end
end
