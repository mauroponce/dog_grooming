class Extra < ApplicationRecord
  belongs_to :business
  has_many :appointment_extras, dependent: :restrict_with_error

  validates :title, presence: true
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  normalizes :title, :description, with: ->(value) { value.to_s.strip.presence }

  scope :active, -> { where(active: true) }
  scope :publicly_visible, -> { active.where(public_visible: true) }

  def price
    price_cents.to_i / 100.0
  end

  def price=(value)
    self.price_cents = (BigDecimal(value.to_s.presence || "0") * 100).to_i
  end
end
