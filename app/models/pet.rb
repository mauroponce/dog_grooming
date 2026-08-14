class Pet < ApplicationRecord
  SIZE_OPTIONS = {
    "extra_small" => "Mini",
    "small" => "Chico",
    "medium" => "Mediano",
    "large" => "Grande",
    "extra_large" => "Gigante"
  }.freeze

  SEX_OPTIONS = {
    "female" => "Hembra",
    "male" => "Macho"
  }.freeze

  belongs_to :business, inverse_of: :pets
  belongs_to :customer_profile, inverse_of: :pets

  # Keep the legacy name available while new grooming flows use bookings.
  has_many :appointments, dependent: :nullify, inverse_of: :pet
  has_many :bookings, class_name: "Booking", foreign_key: :pet_id, inverse_of: :pet

  before_validation :assign_business_from_customer_profile
  before_validation :normalize_attributes

  validates :name, presence: true, length: { maximum: 120 }
  validates :breed, length: { maximum: 120 }, allow_blank: true
  validates :size, inclusion: { in: SIZE_OPTIONS.keys }, allow_blank: true
  validates :sex, inclusion: { in: SEX_OPTIONS.keys }, allow_blank: true
  validates :notes, length: { maximum: 10_000 }, allow_blank: true

  validate :customer_profile_belongs_to_business
  validate :birth_date_cannot_be_in_the_future

  scope :alphabetically, -> { order(Arel.sql("LOWER(name) ASC"), :id) }

  def size_label
    SIZE_OPTIONS[size]
  end

  def sex_label
    SEX_OPTIONS[sex]
  end

  private
    def assign_business_from_customer_profile
      self.business ||= customer_profile&.business
    end

    def normalize_attributes
      self.name = name.to_s.squish.presence
      self.breed = breed.to_s.squish.presence
      self.size = normalize_size(size)
      self.sex = normalize_sex(sex)
      self.notes = notes.to_s.strip.presence
    end

    def normalize_size(value)
      normalized = value.to_s.squish.downcase.presence
      {
        "mini" => "extra_small",
        "muy chico" => "extra_small",
        "muy chica" => "extra_small",
        "chico" => "small",
        "chica" => "small",
        "pequeno" => "small",
        "pequeño" => "small",
        "mediano" => "medium",
        "mediana" => "medium",
        "grande" => "large",
        "gigante" => "extra_large"
      }.fetch(normalized, normalized)
    end

    def normalize_sex(value)
      normalized = value.to_s.squish.downcase.presence
      {
        "hembra" => "female",
        "femenino" => "female",
        "macho" => "male",
        "masculino" => "male"
      }.fetch(normalized, normalized)
    end

    def customer_profile_belongs_to_business
      return if customer_profile_id.blank? || business_id.blank?
      return if customer_profile&.business_id == business_id

      errors.add(:customer_profile, "no pertenece a este negocio")
    end

    def birth_date_cannot_be_in_the_future
      return if birth_date.blank? || birth_date <= Date.current

      errors.add(:birth_date, "no puede ser futura")
    end
end
