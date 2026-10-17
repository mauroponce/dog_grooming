class PetSizeBand < ApplicationRecord
  belongs_to :business
  has_many :service_variants, dependent: :restrict_with_error
  has_many :pets, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :business_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, uniqueness: { scope: :business_id }
  validates :minimum_weight_kg, numericality: { greater_than_or_equal_to: 0 }
  validates :maximum_weight_kg, numericality: { greater_than: :minimum_weight_kg }, allow_nil: true

  scope :ordered, -> { order(:position, :minimum_weight_kg) }

  def weight_label
    return "Hasta #{maximum_weight_kg.to_i} kg" if minimum_weight_kg.zero? && maximum_weight_kg.present?
    if maximum_weight_kg.blank?
      lower_boundary = minimum_weight_kg.frac.zero? && minimum_weight_kg.positive? ? minimum_weight_kg.to_i - 1 : minimum_weight_kg.to_f
      return "Más de #{lower_boundary} kg"
    end

    "#{minimum_weight_kg.to_i}–#{maximum_weight_kg.to_i} kg"
  end
end
