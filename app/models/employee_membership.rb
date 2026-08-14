class EmployeeMembership < ApplicationRecord
  include PurgesReplacedAttachedBlobs

  PROFILE_PHOTO_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp].freeze
  PROFILE_PHOTO_MAX_SIZE = 5.megabytes
  CALENDAR_COLORS = {
    "#ef4444" => "Rojo",
    "#f97316" => "Naranja",
    "#f59e0b" => "Amarillo",
    "#84cc16" => "Lima",
    "#22c55e" => "Verde",
    "#14b8a6" => "Turquesa",
    "#06b6d4" => "Cian",
    "#3b82f6" => "Azul",
    "#ffded4" => "Durazno",
    "#ec4899" => "Rosa"
  }.freeze

  PERMISSIONS = {
    "can_view_all_bookings" => "Ver todos los turnos",
    "can_create_bookings" => "Crear turnos",
    "can_edit_bookings" => "Editar turnos",
    "can_complete_own_bookings" => "Finalizar turnos propios",
    "can_complete_all_bookings" => "Finalizar todos los turnos",
    "can_cancel_bookings" => "Cancelar turnos",
    "can_approve_deposits" => "Aprobar comprobantes",
    "can_reject_deposits" => "Rechazar comprobantes",
    "can_view_all_customers" => "Ver todas las clientes",
    "can_view_customer_history" => "Ver historial de clientas asignadas",
    "can_edit_customers" => "Editar clientes",
    "can_edit_internal_notes" => "Editar notas internas",
    "can_delete_internal_attachments" => "Eliminar adjuntos internos",
    "can_manage_services" => "Gestionar servicios y precios",
    "can_manage_availability" => "Gestionar disponibilidad",
    "can_manage_resources" => "Gestionar recursos",
    "can_view_sales_dashboard" => "Ver ventas",
    "can_manage_sales_campaigns" => "Gestionar campañas",
    "can_manage_campaign_links" => "Gestionar links de campaña",
    "can_manage_packs" => "Gestionar packs",
    "can_manage_gift_cards" => "Gestionar gift cards",
    "can_manage_referrals" => "Gestionar referidos",
    "can_manage_public_presence" => "Gestionar presencia online",
    "can_manage_service_forms" => "Gestionar formularios previos",
    "can_manage_promotions" => "Gestionar promos"
  }.freeze
  DEFAULT_PERMISSIONS = %w[
    can_create_bookings
    can_edit_bookings
    can_complete_own_bookings
    can_view_customer_history
    can_edit_internal_notes
  ].freeze
  ACCESS_LEVELS = {
    "none" => {
      label: "Sin acceso",
      description: "Sin acceso a las herramientas del workspace.",
      permissions: []
    },
    "basic" => {
      label: "Básico",
      description: "Acceso parcial a calendario y turnos. No ve ventas ni facturación.",
      permissions: %w[
        can_create_bookings
        can_edit_bookings
        can_complete_own_bookings
      ]
    },
    "low" => {
      label: "Bajo",
      description: "Acceso operativo a calendario, turnos y datos básicos de clientes.",
      permissions: %w[
        can_view_all_bookings
        can_create_bookings
        can_edit_bookings
        can_complete_own_bookings
        can_cancel_bookings
        can_view_customer_history
        can_edit_internal_notes
      ]
    },
    "medium" => {
      label: "Medio",
      description: "Acceso a calendario, clientes, comprobantes y operación diaria. Sin ventas ni facturación.",
      permissions: %w[
        can_view_all_bookings
        can_create_bookings
        can_edit_bookings
        can_complete_own_bookings
        can_complete_all_bookings
        can_cancel_bookings
        can_approve_deposits
        can_reject_deposits
        can_view_all_customers
        can_view_customer_history
        can_edit_customers
        can_edit_internal_notes
      ]
    },
    "high" => {
      label: "Alto",
      description: "Acceso amplio a operación, clientes, servicios, horarios y presencia online. Sin superadmin, ventas ni facturación.",
      permissions: %w[
        can_view_all_bookings
        can_create_bookings
        can_edit_bookings
        can_complete_own_bookings
        can_complete_all_bookings
        can_cancel_bookings
        can_approve_deposits
        can_reject_deposits
        can_view_all_customers
        can_view_customer_history
        can_edit_customers
        can_edit_internal_notes
        can_delete_internal_attachments
        can_manage_services
        can_manage_availability
        can_manage_resources
        can_manage_public_presence
        can_manage_service_forms
        can_manage_promotions
      ]
    }
  }.freeze
  PERMISSION_ALIASES = {
    "appointments_manage" => %w[can_create_bookings can_edit_bookings],
    "appointments_all" => %w[can_view_all_bookings],
    "deposits_review" => %w[can_approve_deposits can_reject_deposits],
    "services_manage" => %w[can_manage_services],
    "availability_manage" => %w[can_manage_availability],
    "customers_manage" => %w[can_view_all_customers can_edit_customers can_edit_internal_notes],
    "analytics_view" => %w[can_view_all_bookings],
    "resources_manage" => %w[can_manage_resources],
    "pricing_manage" => %w[can_manage_services],
    "sales_view" => %w[can_view_sales_dashboard],
    "sales_campaigns_manage" => %w[can_manage_sales_campaigns],
    "campaign_links_manage" => %w[can_manage_campaign_links],
    "packs_manage" => %w[can_manage_packs],
    "gift_cards_manage" => %w[can_manage_gift_cards],
    "referrals_manage" => %w[can_manage_referrals],
    "public_presence_manage" => %w[can_manage_public_presence],
    "service_forms_manage" => %w[can_manage_service_forms],
    "promotions_manage" => %w[can_manage_promotions]
  }.freeze
  STATUSES = %w[pending active revoked].freeze

  attr_reader :raw_invitation_token

  belongs_to :business, counter_cache: true, touch: true
  belongs_to :user, optional: true
  belongs_to :branch, optional: true
  belongs_to :invited_by, class_name: "User", optional: true
  has_many :employee_availability_rules, dependent: :destroy
  has_many :appointments, dependent: :nullify
  has_many :booking_notes, dependent: :nullify
  has_many :sales_opportunities, dependent: :nullify
  has_many :availability_blocks, dependent: :destroy
  has_many :service_professionals, dependent: :destroy
  has_many :services, through: :service_professionals
  has_one_attached :profile_photo
  purge_replaced_attached_blobs_for :profile_photo

  before_validation :normalize_email_address
  before_validation :normalize_profile_fields
  before_validation :ensure_default_permissions
  after_create :ensure_availability_rules!
  after_commit :broadcast_realtime_updates_later, on: %i[create update destroy]

  validates :name, :email_address, :status, presence: true
  validates :calendar_color, inclusion: { in: CALENDAR_COLORS.keys }, allow_blank: true
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :email_address, uniqueness: { scope: :business_id }
  validates :status, inclusion: { in: STATUSES }
  validate :required_name_parts_for_profile_changes
  validate :branch_belongs_to_business
  validate :profile_photo_is_valid

  scope :active, -> { where(status: "active") }
  scope :pending, -> { where(status: "pending") }
  scope :receives_appointments, -> { where(can_receive_appointments: true) }
  scope :available_for_booking, -> { active.receives_appointments.where(archived_at: nil) }
  scope :ordered, -> { order(Arel.sql("CASE status WHEN 'active' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END"), :sort_order, :name) }

  def invite!(invited_by:)
    generate_invitation_token!
    update!(
      invited_by: invited_by,
      status: "pending",
      invitation_sent_at: Time.current,
      invitation_expires_at: 7.days.from_now
    )
    EmployeeInvitationsMailer.invite(self, raw_invitation_token).deliver_later
  end

  def reinvite!(invited_by:)
    invite!(invited_by:)
  end

  def accept!(user:)
    update!(
      user: user,
      status: "active",
      invitation_accepted_at: Time.current,
      invitation_token_digest: nil,
      invitation_expires_at: nil
    )
  end

  def revoke!
    update!(status: "revoked", archived_at: Time.current)
  end

  def active?
    status == "active"
  end

  def pending?
    status == "pending"
  end

  def revoked?
    status == "revoked"
  end

  def expired?
    invitation_expires_at.present? && invitation_expires_at.past?
  end

  def can?(permission)
    permission = permission.to_s
    if PERMISSIONS.key?(permission)
      return true if permissions[permission].present?

      return PERMISSION_ALIASES.any? do |legacy_key, canonical_keys|
        canonical_keys.include?(permission) && permissions[legacy_key].present?
      end
    end

    Array(PERMISSION_ALIASES[permission]).any? { |canonical| permissions[canonical].present? || permissions[permission].present? }
  end

  def permission_keys=(keys)
    canonical_keys = Array(keys).flat_map { |key| canonical_permission_keys(key) }.uniq
    self.permissions = canonical_keys.index_with { true }
  end

  def permission_keys
    PERMISSIONS.keys.select { |key| can?(key) }
  end

  def access_level=(level)
    self.permission_keys = ACCESS_LEVELS.fetch(level.to_s, ACCESS_LEVELS.fetch("basic")).fetch(:permissions)
  end

  def access_level
    return "owner" if owner_profile?

    keys = permission_keys
    return "none" if keys.blank?

    exact_level = ACCESS_LEVELS.find do |_level, config|
      Array(config.fetch(:permissions)).sort == keys.sort
    end
    return exact_level.first if exact_level

    return "high" if can?("can_manage_services") || can?("can_manage_availability") || can?("can_manage_public_presence") || can?("can_manage_service_forms")
    return "medium" if can?("can_approve_deposits") || can?("can_reject_deposits") || can?("can_view_all_customers")
    return "low" if can?("can_view_all_bookings")

    "basic"
  end

  def access_level_label
    return "Propietario del espacio de trabajo" if owner_profile?

    ACCESS_LEVELS.fetch(access_level, ACCESS_LEVELS.fetch("basic")).fetch(:label)
  end

  def access_level_description
    return "Acceso total al negocio. No incluye rutas de superadmin." if owner_profile?

    ACCESS_LEVELS.fetch(access_level, ACCESS_LEVELS.fetch("basic")).fetch(:description)
  end

  def label
    [ display_name, branch&.name ].compact_blank.join(" - ")
  end

  def display_name
    return user.name.presence || name if owner_profile?

    name
  end

  def effective_profile_photo
    return user.profile_photo if user&.profile_photo&.attached?

    profile_photo
  end

  def initials
    name.to_s.split.first(2).map { |part| part.first&.upcase }.join.presence || "PR"
  end

  def role_label
    return "Admin" if owner_profile?

    can?("can_view_all_bookings") ? "Recepción" : "Profesional"
  end

  def owner_profile?
    business&.owner_id.present? && user_id == business.owner_id
  end

  def specialty_label
    specialty.presence || inferred_specialty || "General"
  end

  def archived?
    archived_at.present? || revoked?
  end

  def billable_professional?
    active? && !archived? && can_receive_appointments?
  end

  def invited?
    pending?
  end

  def whatsapp_url(text: nil)
    return "" if phone.blank?

    PhoneNumber.whatsapp_link(phone, text: text)
  end

  def last_access_at
    user&.sessions&.maximum(:created_at)
  end

  def ensure_availability_rules!
    existing_weekdays = employee_availability_rules.pluck(:weekday)
    Business::DAYS.each do |weekday, _name|
      next if existing_weekdays.include?(weekday)

      business_rule = business.availability_rules.find_by(weekday: weekday)
      employee_availability_rules.create!(
        weekday: weekday,
        active: business_rule&.active? || false,
        start_time: business_rule&.start_time || "09:00",
        end_time: business_rule&.end_time || "18:00"
      )
    end
  end

  def self.find_pending_by_token(token)
    pending.where("invitation_expires_at > ?", Time.current).find do |membership|
      membership.invitation_token_matches?(token)
    end
  end

  def invitation_token_matches?(token)
    return false if invitation_token_digest.blank? || token.blank?

    BCrypt::Password.new(invitation_token_digest).is_password?(token)
  end

  private
    def generate_invitation_token!
      @raw_invitation_token = SecureRandom.urlsafe_base64(32)
      self.invitation_token_digest = BCrypt::Password.create(@raw_invitation_token)
    end

    def normalize_email_address
      self.email_address = email_address.to_s.strip.downcase
    end

    def normalize_profile_fields
      self.first_name = first_name.to_s.strip.presence
      self.last_name = last_name.to_s.strip.presence
      self.name = [ first_name, last_name ].compact_blank.join(" ").presence || name.to_s.strip
      self.phone = phone.present? ? PhoneNormalizer.normalize(phone) : nil
      self.additional_phone = additional_phone.present? ? PhoneNormalizer.normalize(additional_phone) : nil if has_attribute?(:additional_phone)
      self.specialty = specialty.to_s.strip.presence
      self.calendar_color = calendar_color.presence || CALENDAR_COLORS.keys.first if has_attribute?(:calendar_color)
    end

    def ensure_default_permissions
      self.permissions = DEFAULT_PERMISSIONS.index_with { true } if permissions.nil?
      self.permission_keys = permissions.to_h.select { |_key, enabled| enabled }.keys
    end

    def branch_belongs_to_business
      return if branch.blank? || business.blank? || branch.business_id == business_id

      errors.add(:branch, "no pertenece a este negocio")
    end

    def profile_photo_is_valid
      return unless profile_photo.attached?

      unless profile_photo.blob.content_type.in?(PROFILE_PHOTO_CONTENT_TYPES)
        errors.add(:profile_photo, "debe ser JPG, PNG o WebP")
      end

      if profile_photo.blob.byte_size > PROFILE_PHOTO_MAX_SIZE
        errors.add(:profile_photo, "no puede superar 5 MB")
      end
    end

    def required_name_parts_for_profile_changes
      return unless new_record? || will_save_change_to_first_name? || will_save_change_to_last_name?

      errors.add(:first_name, "no puede estar en blanco") if first_name.blank?
      errors.add(:last_name, "no puede estar en blanco") if last_name.blank?
    end

    def inferred_specialty
      categories = services.map(&:category_label).uniq.first(2)
      categories.to_sentence.presence
    end

    def canonical_permission_keys(key)
      key = key.to_s
      return key if PERMISSIONS.key?(key)

      PERMISSION_ALIASES.fetch(key, [])
    end

    def broadcast_realtime_updates_later
      PublicBooking::BroadcastServicesJob.perform_later(business_id)
    end
end
