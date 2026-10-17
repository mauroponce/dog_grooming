class Pet < ApplicationRecord
  include PurgesReplacedAttachedBlobs

  SEX_OPTIONS = {
    "female" => "Hembra",
    "male" => "Macho"
  }.freeze
  COAT_TYPES = {
    "short" => "Corto",
    "long" => "Largo",
    "double" => "Doble",
    "curly" => "Rizado / lanoso",
    "other" => "Otro"
  }.freeze
  BEHAVIORAL_ALERTS = {
    "blower_fear" => "Se asusta con la turbina",
    "bite_risk" => "Puede morder",
    "paw_sensitive" => "Sensible en las patas",
    "skin_sensitive" => "Piel sensible",
    "senior_special_care" => "Requiere cuidado especial por edad"
  }.freeze
  GROOMING_REFERENCE_PHOTO_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp].freeze
  GROOMING_REFERENCE_PHOTO_MAX_SIZE = 10.megabytes

  belongs_to :business, inverse_of: :pets
  belongs_to :customer_profile, inverse_of: :pets
  belongs_to :pet_size_band, optional: true

  # Keep the legacy name available while new grooming flows use bookings.
  has_many :appointments, dependent: :nullify, inverse_of: :pet
  has_many :bookings, class_name: "Booking", foreign_key: :pet_id, inverse_of: :pet
  has_one_attached :grooming_reference_photo
  purge_replaced_attached_blobs_for :grooming_reference_photo

  before_validation :assign_business_from_customer_profile
  before_validation :normalize_attributes

  validates :name, presence: true, length: { maximum: 120 }
  validates :breed, length: { maximum: 120 }, allow_blank: true
  validates :sex, inclusion: { in: SEX_OPTIONS.keys }, allow_blank: true
  validates :notes, length: { maximum: 10_000 }, allow_blank: true
  validates :coat_type, inclusion: { in: COAT_TYPES.keys }, allow_blank: true
  validates :coat_details, length: { maximum: 250 }, allow_blank: true
  validates :grooming_reference_note, length: { maximum: 2_000 }, allow_blank: true

  validate :customer_profile_belongs_to_business
  validate :birth_date_cannot_be_in_the_future
  validate :coat_details_required_for_other
  validate :behavioral_alerts_are_valid
  validate :grooming_reference_photo_is_valid
  validate :pet_size_band_belongs_to_business

  scope :alphabetically, -> { order(Arel.sql("LOWER(name) ASC"), :id) }

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
      self.sex = normalize_sex(sex)
      self.notes = notes.to_s.strip.presence
      self.coat_type = coat_type.to_s.squish.downcase.presence
      self.coat_details = coat_details.to_s.squish.presence
      self.coat_details = nil unless coat_type == "other"
      self.grooming_reference_note = grooming_reference_note.to_s.strip.presence
      self.behavioral_alerts = behavioral_alerts.map { |alert| alert.to_s.squish }.compact_blank.uniq if behavioral_alerts.is_a?(Array)
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

    def coat_details_required_for_other
      return unless coat_type == "other" && coat_details.blank?

      errors.add(:coat_details, "explicá el tipo de manto")
    end

    def behavioral_alerts_are_valid
      unless behavioral_alerts.is_a?(Array)
        errors.add(:behavioral_alerts, "debe ser una lista")
        return
      end

      invalid = behavioral_alerts - BEHAVIORAL_ALERTS.keys
      errors.add(:behavioral_alerts, "incluye alertas inválidas") if invalid.any?
    end

    def grooming_reference_photo_is_valid
      return unless grooming_reference_photo.attached?

      unless grooming_reference_photo.content_type.to_s.in?(GROOMING_REFERENCE_PHOTO_CONTENT_TYPES)
        errors.add(:grooming_reference_photo, "debe ser JPG, PNG o WebP")
      end
      if grooming_reference_photo.byte_size.to_i > GROOMING_REFERENCE_PHOTO_MAX_SIZE
        errors.add(:grooming_reference_photo, "no puede superar 10 MB")
      end
    end

    def pet_size_band_belongs_to_business
      return if pet_size_band.blank? || pet_size_band.business_id == business_id

      errors.add(:pet_size_band, "no pertenece a esta peluquería")
    end
end
