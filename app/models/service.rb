class Service < ApplicationRecord
  include PurgesReplacedAttachedBlobs

  DURATIONS = (15..240).step(15).to_a.freeze
  PUBLIC_START_INTERVALS = [ 15, 30, 60 ].freeze
  VISIBILITY_MODES = %w[public hidden link_only].freeze
  PROFESSIONAL_SELECTION_MODES = %w[hidden optional required].freeze

  belongs_to :business, counter_cache: true, touch: true
  belongs_to :service_category, optional: true
  belongs_to :service_catalog_item, optional: true
  belongs_to :payment_account, optional: true
  has_many :appointments, dependent: :restrict_with_error
  has_many :service_resources, dependent: :destroy
  has_many :bookable_resources, through: :service_resources
  has_many :service_availability_rules, dependent: :destroy
  has_many :service_professionals, dependent: :destroy
  has_many :employee_memberships, through: :service_professionals
  has_many :service_tags, dependent: :destroy
  has_many :service_recommendations, dependent: :destroy
  has_many :recommended_services, through: :service_recommendations
  has_many :inverse_service_recommendations, class_name: "ServiceRecommendation", foreign_key: :recommended_service_id, dependent: :destroy, inverse_of: :recommended_service
  has_one_attached :cover_image
  has_many_attached :service_images
  purge_replaced_attached_blobs_for :cover_image

  validates :name, :category, presence: true
  validates :slug,
    presence: true,
    uniqueness: { scope: :business_id, case_sensitive: false },
    format: { with: Slugs::GenerateUnique::FORMAT },
    length: { in: Slugs::GenerateUnique::MIN_LENGTH..Slugs::GenerateUnique::MAX_LENGTH }
  validates :duration_minutes, inclusion: { in: DURATIONS }
  validates :public_start_interval_minutes, inclusion: { in: PUBLIC_START_INTERVALS }, allow_nil: true
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :deposit_amount_cents, :deposit_payment_deadline_minutes, :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :recommended_follow_up_days, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 365 }, allow_blank: true
  validates :visibility_mode, inclusion: { in: VISIBILITY_MODES }
  validates :professional_selection_mode, inclusion: { in: PROFESSIONAL_SELECTION_MODES }
  validate :availability_date_range_is_valid
  validate :payment_account_belongs_to_business
  validate :payment_amount_is_configured
  normalizes :category, :description, :includes, :before_care, :after_care, with: ->(value) { value.to_s.strip.presence }
  before_validation :sync_service_category, :ensure_slug, :clear_availability_dates_without_limit
  after_save :sync_tags_from_text!, if: -> { defined?(@tags_text) && @tags_text != nil }
  after_commit :ensure_business_deposits_enabled!, on: %i[create update], if: -> { self[:deposit_required] }
  after_commit :broadcast_public_services_later, on: %i[create update destroy]

  scope :active, -> { where(active: true, archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :publicly_bookable, -> {
    active
      .where(visibility_mode: "public", public_visible: true)
      .where("services.name <> '' AND services.duration_minutes > 0")
  }
  scope :publicly_accessible, -> {
    active
      .where(visibility_mode: %w[public link_only], public_visible: true)
      .where("services.name <> '' AND services.duration_minutes > 0")
  }

  CATEGORIES = [
    "General",
    "Uñas",
    "Depilación",
    "Facial",
    "Corporal",
    "Cejas y pestañas",
    "Pestañas",
    "Masajes",
    "Aparatología",
    "Medicina estética",
    "Postoperatorio",
    "Capilar",
    "Bronceado",
    "Spa",
    "Salud",
    "Terapia",
    "Nutrición"
  ].freeze

  def price
    price_cents.to_i / 100.0
  end

  def price=(value)
    self.price_cents = (BigDecimal(value.to_s.presence || "0") * 100).to_i
  end

  def deposit_amount
    deposit_amount_cents.to_i / 100.0
  end

  def deposit_amount=(value)
    self.deposit_amount_cents = (BigDecimal(value.to_s.presence || "0") * 100).to_i
  end

  def display_price
    return "Sin precio" if price_cents.zero?

    price_label_for_cents(price_cents)
  end

  def price_cents_for_time(_datetime, _center = business)
    price_cents
  end

  def price_for_time(datetime, center = business)
    price_cents_for_time(datetime, center) / 100.0
  end

  def dynamic_discount_for_time(_datetime, _center = business)
    0.to_d
  end

  def price_label_for_cents(cents)
    return "Consultar" if cents.to_i.zero?

    "$#{(cents.to_i / 100).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
  end

  def deposit_amount_cents_for(total_cents)
    return 0 unless deposit_required?

    total_cents = total_cents.to_i
    return deposit_amount_cents.to_i unless total_cents.positive?
    [ deposit_amount_cents.to_i, total_cents ].min
  end

  def expected_deposit_amount_cents
    deposit_amount_cents_for(price_cents)
  end

  def deposit_summary
    return "Sin seña" unless deposit_required?
    "#{price_label_for_cents(deposit_amount_cents)} de seña"
  end

  def deposit_required?
    return false unless self[:deposit_required]
    return false unless business&.deposits_enabled?

    deposit_amount_cents.positive?
  end

  def effective_payment_account
    return payment_account if payment_account.present? && payment_account.active? && payment_account.business_id == business_id

    business&.primary_payment_account
  end

  def deposit_payment_details
    effective_payment_account&.details.presence || business&.legacy_payment_account_details
  end

  def deposit_payment_reference
    effective_payment_account&.payment_reference.presence ||
      business&.deposit_alias.presence ||
      business&.deposit_account.presence ||
      business&.deposit_payment_link.presence ||
      "los datos de seña del centro"
  end

  def deposit_payment_configured?
    manual_payment_configured?
  end

  def manual_payment_configured?
    external_payment_link.present? || deposit_payment_details.present?
  end

  def mercado_pago_payment_configured?
    business&.mercado_pago_connected?
  end

  def public?
    visibility_mode == "public" && public_visible? && active? && archived_at.blank? && complete?
  end

  def hide_professional_selection?
    professional_selection_mode == "hidden"
  end

  def optional_professional_selection?
    professional_selection_mode == "optional"
  end

  def require_professional_selection?
    professional_selection_mode == "required"
  end

  def hidden?
    visibility_mode == "hidden" || !active?
  end

  def link_only?
    visibility_mode == "link_only"
  end

  def archived?
    archived_at.present?
  end

  def complete?
    name.present? && category.present? && duration_minutes.present?
  end

  def incomplete?
    !complete?
  end

  def visibility_label
    return "Archivado" if archived?
    return "Completar" if incomplete?

    {
      "public" => "Público",
      "hidden" => "Oculto",
      "link_only" => "Solo por link"
    }.fetch(visibility_mode, "Público")
  end

  def tags_text
    service_tags.order(:tag_type, :name).pluck(:name).join(", ")
  end

  def tags_text=(value)
    @tags_text = value
  end

  def sync_tags_from_text!
    return if @tags_text.nil?

    names = @tags_text.to_s.split(",").map { |tag| tag.strip.downcase }.compact_blank.uniq
    service_tags.destroy_all
    names.each do |name|
      service_tags.create!(name:, tag_type: "keyword")
    end
  end

  def archive!
    update!(active: false, archived_at: Time.current, visibility_mode: "hidden")
  end

  def effective_public_start_interval_minutes
    duration_minutes.to_i
  end

  def available_on_date?(date)
    date = date.to_date
    if limit_availability_by_date?
      return false if availability_starts_on.present? && date < availability_starts_on
      return false if availability_ends_on.present? && date > availability_ends_on
    end

    return true unless use_advanced_availability?

    active_availability_rules_for(date.wday).any?
  end

  def active_availability_rules_for(weekday)
    if association(:service_availability_rules).loaded?
      service_availability_rules.select { |rule| rule.active? && rule.weekday == weekday }
    else
      service_availability_rules.active.where(weekday: weekday).to_a
    end
  end

  def public_service_url
    return "" if business.blank? || slug.blank?

    PublicLinks::UrlBuilder.service(self)
  end

  def category_label
    label = service_category&.name.presence || category.presence || "General"
    normalized = I18n.transliterate(label).downcase
    return "Uñas" if normalized == "unas"
    return "Depilación" if normalized == "depilacion"

    label
  end

  def icon_key
    case category_label.downcase
    when /uña|unas|manic/
      "nails"
    when /facial|piel|medicina estética|capilar/
      "face"
    when /corporal|masaje|drenaje|spa|postoperatorio/
      "spark"
    when /depil/
      "flash"
    when /salud|terapia|psico|nutri/
      "health"
    when /barba|cabello|corte|afeitado|combo/
      "scissors"
    else
      "calendar"
    end
  end

  def accent_classes
    case icon_key
    when "nails"
      "bg-rose-50 text-rose-600"
    when "face"
      "bg-sky-50 text-sky-600"
    when "spark"
      "bg-emerald-50 text-emerald-600"
    when "flash"
      "bg-amber-50 text-amber-600"
    when "health"
      "bg-teal-50 text-teal-600"
    when "scissors"
      "bg-zinc-100 text-zinc-700"
    else
      "bg-brand-50 text-brand-600"
    end
  end

  private
    def ensure_slug
      return if business.blank?

      self.slug = Slugs::GenerateUnique.call(slug.presence || name, scope: business.services, current_record: self)
    end

    def sync_service_category
      return if business.blank?

      if service_category.present?
        self.category = service_category.name
        return
      end

      category_name = category.presence || "General"
      self.service_category = ServiceCategory.find_or_create_for!(business:, name: category_name)
      self.category = service_category.name
    end

    def payment_amount_is_configured
      return unless deposit_required
      return if deposit_amount_cents.to_i.positive?

      errors.add(:deposit_amount, "debe estar definido para pedir pago de seña")
    end

    def payment_account_belongs_to_business
      return if payment_account.blank? || business.blank? || payment_account.business_id == business_id

      errors.add(:payment_account, "no pertenece a este negocio")
    end

    def clear_availability_dates_without_limit
      return if limit_availability_by_date?

      self.availability_starts_on = nil
      self.availability_ends_on = nil
    end

    def availability_date_range_is_valid
      return unless limit_availability_by_date?
      return if availability_starts_on.blank? || availability_ends_on.blank?

      errors.add(:availability_ends_on, "debe ser posterior o igual a la fecha de inicio") if availability_ends_on < availability_starts_on
    end

    def broadcast_public_services_later
      PublicBooking::BroadcastServicesJob.perform_later(business_id)
    end

    def ensure_business_deposits_enabled!
      return if business.blank? || business.deposits_enabled?

      business.update!(preferences: business.preferences.to_h.merge("deposits_enabled" => true))
    end
end
