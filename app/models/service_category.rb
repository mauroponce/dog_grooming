class ServiceCategory < ApplicationRecord
  include PurgesReplacedAttachedBlobs

  COVER_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp].freeze
  COVER_IMAGE_MAX_SIZE = 10.megabytes

  belongs_to :business, touch: true
  belongs_to :service_catalog_category, optional: true
  has_many :services, dependent: :nullify
  has_one_attached :cover_image
  purge_replaced_attached_blobs_for :cover_image

  validates :name, presence: true
  validates :slug,
    presence: true,
    uniqueness: { scope: :business_id, case_sensitive: false },
    format: { with: Slugs::GenerateUnique::FORMAT },
    length: { in: Slugs::GenerateUnique::MIN_LENGTH..Slugs::GenerateUnique::MAX_LENGTH }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :single_primary_category_per_business
  validate :cover_image_is_valid
  validate :whatsapp_category_limit
  around_save :lock_category_business

  normalizes :name, :slug, :description, with: ->(value) { value.to_s.strip.presence }

  before_validation :ensure_slug

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(primary_category: :desc, sort_order: :asc, name: :asc) }

  def self.slug_for(name)
    slug = I18n.transliterate(name.to_s)
      .downcase
      .gsub(/[^a-z0-9]+/, "-")
      .gsub(/\A-|-+\z/, "")

    slug.presence || "categoria"
  end

  def self.find_or_create_for!(business:, name:, service_catalog_category: nil, primary_category: false)
    normalized_name = name.to_s.strip
    slug = slug_for(normalized_name)

    business.service_categories.find_or_initialize_by(slug: slug).tap do |category|
      category.name = normalized_name
      category.service_catalog_category ||= service_catalog_category
      category.primary_category = primary_category if primary_category
      category.active = true if category.active.nil?
      category.sort_order ||= business.service_categories.maximum(:sort_order).to_i + 1
      category.save!
    end
  end

  private
    def lock_category_business(&block)
      business.with_lock do
        whatsapp_category_limit
        raise ActiveRecord::RecordInvalid, self if errors.any?
        block.call
      end
    end

    def whatsapp_category_limit
      return unless active? && business.present?
      errors.add(:base, "Podés tener hasta nueve categorías activas para WhatsApp.") if business.service_categories.active.where.not(id: id).count >= 9
    end
    def ensure_slug
      return if business.blank?

      base = self.class.slug_for(slug.presence || name)
      self.slug = Slugs::GenerateUnique.call(base, scope: business.service_categories, current_record: self)
    end

    def single_primary_category_per_business
      return unless primary_category? && business.present?

      duplicate = business.service_categories.where(primary_category: true).where.not(id: id).exists?
      errors.add(:primary_category, "ya existe para este negocio") if duplicate
    end

    def cover_image_is_valid
      return unless cover_image.attached?

      unless cover_image.blob.content_type.in?(COVER_IMAGE_CONTENT_TYPES)
        errors.add(:cover_image, "debe ser una imagen PNG, JPG o WebP")
      end

      if cover_image.blob.byte_size > COVER_IMAGE_MAX_SIZE
        errors.add(:cover_image, "no puede superar 10 MB")
      end
    end
end
