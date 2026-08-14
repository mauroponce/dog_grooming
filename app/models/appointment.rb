require "securerandom"
require "uri"

class Appointment < ApplicationRecord
  include PurgesReplacedAttachedBlobs

  STATUS_LABELS = {
    "pending" => "A confirmar",
    "confirmed" => "Confirmado",
    "canceled" => "Cancelado",
    "pending_payment" => "Pago pendiente",
    "pending_confirmation" => "Confirmado",
    "pending_deposit" => "Pago pendiente",
    "pending_deposit_review" => "Comprobante",
    "deposit_rejected" => "Seña pendiente",
    "expired" => "Vencido",
    "completed" => "Finalizado",
    "no_show" => "No asistió",
    "rescheduled" => "Reprogramado"
  }.freeze

  STATUS_FULL_LABELS = STATUS_LABELS.merge(
    "pending_deposit_review" => "Comprobante en revisión"
  ).freeze

  STATUS_TONES = {
    "pending" => :amber,
    "confirmed" => :emerald,
    "canceled" => :zinc,
    "pending_payment" => :rose,
    "pending_confirmation" => :emerald,
    "pending_deposit" => :rose,
    "pending_deposit_review" => :amber,
    "deposit_rejected" => :rose,
    "expired" => :zinc,
    "completed" => :violet,
    "no_show" => :rose,
    "rescheduled" => :zinc
  }.freeze

  SOURCE_LABELS = {
    "public_booking" => "Reserva pública",
    "manual" => "Manual"
  }.freeze

  DEPOSIT_STATUS_LABELS = {
    "not_required" => "Sin seña",
    "pending" => "Pago pendiente",
    "submitted" => "Comprobante en revisión",
    "approved" => "Pago aprobado",
    "rejected" => "Comprobante rechazado",
    "failed" => "Error en comprobante",
    "refunded" => "Pago reintegrado"
  }.freeze

  belongs_to :business
  belongs_to :service
  belongs_to :customer_profile, optional: true
  belongs_to :pet, optional: true
  belongs_to :bookable_resource, optional: true
  belongs_to :branch, optional: true
  belongs_to :employee_membership, optional: true
  belongs_to :waitlist_entry, optional: true
  belongs_to :deposit_reviewed_by, class_name: "User", optional: true
  belongs_to :remaining_balance_paid_by, class_name: "User", optional: true
  belongs_to :completed_by, class_name: "User", optional: true
  belongs_to :canceled_by_user, class_name: "User", optional: true
  has_many :notification_deliveries, dependent: :destroy
  has_many :appointment_addons, dependent: :destroy
  has_many :add_on_services, through: :appointment_addons, source: :service
  has_one :appointment_payment, dependent: :destroy
  has_many :booking_notes, dependent: :destroy
  has_many :booking_attachments, dependent: :destroy
  has_many :sales_opportunities, dependent: :nullify
  has_many :pack_sessions, dependent: :nullify
  has_many :booking_intents, dependent: :nullify
  has_many :service_form_responses, dependent: :destroy
  has_one :booking_attribution, dependent: :destroy
  has_one_attached :deposit_receipt
  has_many_attached :deposit_receipt_history
  purge_replaced_attached_blobs_for :deposit_receipt, :deposit_receipt_history

  DEPOSIT_STATUSES = %w[not_required pending submitted approved rejected failed refunded].freeze
  PAYMENT_COLLECTION_METHODS = %w[none manual_proof mercado_pago].freeze
  PAYMENT_CHARGE_MODES = %w[none deposit].freeze
  DEPOSIT_RECEIPT_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp application/pdf].freeze
  DEPOSIT_RECEIPT_EXTENSIONS = %w[.jpg .jpeg .png .webp .pdf].freeze
  DEPOSIT_RECEIPT_MAX_SIZE = 5.megabytes
  TERMINAL_STATUSES = %w[canceled expired completed no_show rescheduled].freeze
  GMAIL_DOMAINS = %w[gmail.com googlemail.com].freeze
  CUSTOMER_CANCELLATION_ACTORS = %w[customer_portal customer_link].freeze
  SHORT_UUID_BYTES = 9

  enum :status, {
    pending: 0,
    confirmed: 1,
    canceled: 2,
    pending_payment: 3,
    pending_confirmation: 4,
    pending_deposit: 5,
    pending_deposit_review: 6,
    deposit_rejected: 7,
    expired: 8,
    completed: 9,
    no_show: 10,
    rescheduled: 11
  }
  enum :source, { public_booking: 0, manual: 1 }

  def self.status_label(value)
    label_for(value, STATUS_LABELS)
  end

  def self.status_full_label(value)
    label_for(value, STATUS_FULL_LABELS)
  end

  def self.status_tone(value)
    STATUS_TONES.fetch(value.to_s, :zinc)
  end

  def self.source_label(value)
    label_for(value, SOURCE_LABELS)
  end

  def self.deposit_status_label(value)
    label_for(value, DEPOSIT_STATUS_LABELS)
  end

  before_validation :normalize_customer_phone
  before_validation :ensure_short_uuid
  before_validation :ensure_customer_portal_token
  before_validation :ensure_deposit_review_token
  before_validation :set_ends_at
  after_create_commit :broadcast_admin_appointments_refresh_after_create, if: :confirmed?
  after_update_commit :broadcast_admin_appointments_refresh_after_confirmation, if: :confirmed_in_latest_commit?
  after_update_commit :notify_waitlist_for_cancellation, if: :waitlist_relevant_cancellation?

  validates :customer_name, :starts_at, :ends_at, presence: true
  validates :short_uuid, presence: true, uniqueness: true, format: { with: /\A[A-Za-z0-9_-]{12}\z/ }
  validates :customer_portal_token, presence: true, uniqueness: true
  validates :deposit_review_token, presence: true, uniqueness: true
  validates :customer_phone, presence: true, unless: :manual?
  validates :deposit_status, inclusion: { in: DEPOSIT_STATUSES }
  validates :payment_collection_method, inclusion: { in: PAYMENT_COLLECTION_METHODS }
  validates :payment_charge_mode, inclusion: { in: PAYMENT_CHARGE_MODES }
  validates :deposit_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :remaining_balance_paid_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :base_price_cents, :final_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :deposit_receipt_file_is_valid
  validate :service_belongs_to_business
  validate :pet_belongs_to_business
  validate :pet_belongs_to_customer_profile
  validate :resource_belongs_to_business
  validate :branch_belongs_to_business
  validate :employee_belongs_to_business
  validate :employee_required_for_team_plan
  validate :required_resource_selected
  validate :resource_enabled_for_service
  validate :ends_after_start
  validate :does_not_overlap, unless: :canceled?
  validate :employee_not_blocked, unless: :canceled?

  scope :active, -> { where.not(status: statuses.values_at(*TERMINAL_STATUSES)) }
  scope :awaiting_customer_action, -> { where(status: statuses.values_at("pending", "pending_payment", "pending_confirmation", "pending_deposit", "deposit_rejected")) }
  scope :awaiting_deposit_review, -> { where(status: statuses[:pending_deposit_review]) }
  scope :upcoming, -> { active.where("starts_at >= ?", Time.current).order(:starts_at) }
  scope :without_deleted_customer, -> {
    deleted_customer_ids = CustomerProfile.unscoped.deleted.select(:id)
    where.not(customer_profile_id: deleted_customer_ids).or(where(customer_profile_id: nil))
  }
  default_scope { without_deleted_customer }

  def confirm!
    update!(status: :confirmed, confirmed_at: Time.current)
  end

  def cancel!(by:, reason: nil)
    return true if canceled?

    actor = cancellation_actor(by)
    transaction do
      update!(
        status: :canceled,
        canceled_at: Time.current,
        canceled_by: actor.fetch(:label),
        canceled_by_user: actor[:user],
        cancellation_reason: reason,
        canceled_late: late_cancellation?
      )
      customer_profile&.register_cancellation!(self)
      create_cancellation_provider_event!(by: actor.fetch(:kind))
    end
  end

  def cancellation_actor_label
    return "Cliente" if canceled_by.to_s.in?(CUSTOMER_CANCELLATION_ACTORS)
    return cancellation_user_label if canceled_by_user.present?
    return "Sistema" if canceled_by == "system"
    return "Administrador" if canceled_by == "admin"

    canceled_by.presence || "No registrado"
  end

  def finalizable?
    confirmed? && starts_at <= 30.minutes.from_now
  end

  def terminal_status?
    status.in?(TERMINAL_STATUSES)
  end

  def late_cancellation?
    Time.current > starts_at - business.cancellation_notice_hours.hours
  end

  def customer_whatsapp_link
    PhoneNumber.whatsapp_link(customer_phone)
  end

  def manual_confirmation_token
    signed_id(expires_in: 14.days, purpose: :appointment_customer_action)
  end

  def manual_confirmation_url
    Rails.application.routes.url_helpers.appointment_action_url(
      token: manual_confirmation_token,
      host: public_app_host,
      protocol: app_protocol
    )
  end

  def manual_whatsapp_message
    lines = [
      "Hola #{customer_name}, te escribimos de #{business.name} por tu turno.",
      "",
      "Servicio: #{service.name}",
      "Fecha: #{customer_starts_at_label}",
      "Lugar: #{business.public_location}"
    ]

    if confirmed?
      lines << "" << "Tu turno ya quedó confirmado. Te esperamos."
    elsif pending_deposit? || deposit_rejected?
      lines << "" << "Para reservarlo necesitamos la seña de #{formatted_deposit_amount}."
      lines << "Datos de pago: #{service.deposit_payment_reference}" if service.deposit_payment_configured?
      lines << "Podés subir el comprobante acá: #{deposit_upload_url}"
    elsif pending_deposit_review?
      lines << "" << "Recibimos tu comprobante y está pendiente de revisión."
    else
      lines << "" << "Te confirmamos por este medio cuando revisemos la disponibilidad."
    end

    lines << "" << customer_portal_management_line if customer_portal_management_line.present?
    lines.join("\n")
  end

  def manual_whatsapp_url
    WhatsApp::MessageBuilder.new(
      business: business,
      template_key: manual_whatsapp_template_key,
      booking: self,
      customer: customer_profile,
      service: service,
      professional: employee_membership
    ).url(phone: customer_phone)
  end

  def customer_starts_at_label
    CustomerDateFormatter.appointment_label(starts_at)
  end

  def status_label
    self.class.status_label(status)
  end

  def source_label
    self.class.source_label(source)
  end

  def deposit_status_label
    self.class.deposit_status_label(deposit_status)
  end

  def deposit_required?
    deposit_status != "not_required"
  end

  def manual_payment_required?
    deposit_required? && payment_collection_method == "manual_proof"
  end

  def mercado_pago_payment_required?
    deposit_required? && payment_collection_method == "mercado_pago"
  end

  def mercado_pago_payment_pending?
    mercado_pago_payment_required? && deposit_pending?
  end

  def deposit_pending?
    deposit_status == "pending"
  end

  def deposit_submitted?
    deposit_status == "submitted"
  end

  def mark_manual_deposit_pending!(amount_cents:, charge_mode: "deposit")
    update!(
      deposit_status: "pending",
      deposit_amount_cents: amount_cents,
      status: :pending_deposit,
      payment_collection_method: "manual_proof",
      deposit_payment_method: manual_payment_method_label,
      payment_charge_mode: charge_mode
    )
  end

  def mark_mercado_pago_payment_pending!(amount_cents:, charge_mode: "deposit")
    update!(
      deposit_status: "pending",
      deposit_amount_cents: amount_cents,
      status: :pending_payment,
      payment_collection_method: "mercado_pago",
      deposit_payment_method: "Mercado Pago",
      payment_charge_mode: charge_mode
    )
  end

  def mark_deposit_submitted!
    update!(
      deposit_status: "submitted",
      status: :pending_deposit_review,
      deposit_submitted_at: Time.current,
      deposit_reviewed_at: nil,
      deposit_rejection_reason: nil
    )
  end

  def mark_deposit_approved!(reviewed_by: nil)
    update!(
      deposit_status: "approved",
      status: :confirmed,
      confirmed_at: confirmed_at || Time.current,
      deposit_reviewed_at: Time.current,
      deposit_reviewed_by: reviewed_by
    )
  end

  def mark_deposit_rejected!(reason: nil, reviewed_by: nil)
    update!(
      deposit_status: "rejected",
      status: :pending_deposit,
      deposit_rejection_reason: reason,
      deposit_reviewed_at: Time.current,
      deposit_reviewed_by: reviewed_by
    )
  end

  def calculated_deposit_amount_cents
    service.deposit_amount_cents_for(final_price_cents)
  end

  def current_total_price_cents
    service&.price_cents.to_i + current_add_ons.sum { |add_on| add_on.service&.price_cents.to_i }
  end

  def remaining_balance_cents
    [ current_total_price_cents - deposit_amount_cents.to_i - remaining_balance_paid_cents.to_i, 0 ].max
  end

  def remaining_balance_paid?
    remaining_balance_paid_at.present?
  end

  def remaining_balance_payable?
    confirmed? && !canceled? && !remaining_balance_paid? && remaining_balance_cents.positive?
  end

  def mark_remaining_balance_paid!(paid_by:)
    with_lock do
      return self if remaining_balance_paid?

      amount_cents = remaining_balance_cents
      raise ArgumentError, "El turno no tiene saldo pendiente para registrar." unless remaining_balance_payable?

      update!(
        remaining_balance_paid_at: Time.current,
        remaining_balance_paid_cents: amount_cents,
        remaining_balance_payment_method: deposit_payment_method_label,
        remaining_balance_paid_by: paid_by
      )
    end
  end

  def deposit_paid_at
    return appointment_payment&.paid_at if payment_collection_method == "mercado_pago"

    deposit_submitted_at || deposit_reviewed_at
  end

  def deposit_payment_method_label
    return "Mercado Pago" if payment_collection_method == "mercado_pago"

    deposit_payment_method.presence || manual_payment_method_label
  end

  def remaining_balance_payment_method_label
    remaining_balance_payment_method.presence || deposit_payment_method_label
  end

  def formatted_deposit_amount
    format_currency(deposit_amount_cents)
  end

  def formatted_remaining_balance
    format_currency(remaining_balance_cents)
  end

  def deposit_review_url
    Rails.application.routes.url_helpers.deposit_review_url(
      token: deposit_review_token.presence || legacy_deposit_review_token,
      host: app_host,
      protocol: app_protocol
    )
  end

  def deposit_upload_token
    signed_id(expires_in: 48.hours, purpose: :deposit_upload)
  end

  def deposit_upload_url
    Rails.application.routes.url_helpers.deposit_receipt_url(
      token: deposit_upload_token,
      host: public_app_host,
      protocol: app_protocol
    )
  end

  def deposit_confirmation_whatsapp_message
    [
      "¡Hola #{customer_name}!",
      "Confirmamos tu seña. Tu turno para #{service.name} queda agendado para #{customer_starts_at_label}.",
      "¡Te esperamos en #{business.name}!",
      customer_portal_management_line
    ].compact.join("\n")
  end

  def deposit_confirmation_whatsapp_url
    PhoneNumber.whatsapp_link(customer_phone, text: deposit_confirmation_whatsapp_message)
  end

  def deposit_rejection_whatsapp_message(reason: nil)
    lines = [
      "Hola #{customer_name}, revisamos el comprobante de seña para tu turno de #{service.name} del #{customer_starts_at_label} y necesitamos que lo vuelvas a cargar.",
      "Podés subir un nuevo comprobante acá: #{deposit_upload_url}",
      customer_portal_management_line
    ].compact
    lines << "Motivo: #{reason}" if reason.present?
    lines.join("\n")
  end

  def deposit_rejection_whatsapp_url(reason: nil)
    PhoneNumber.whatsapp_link(customer_phone, text: deposit_rejection_whatsapp_message(reason:))
  end

  def customer_portal_booking_token
    customer_portal_token
  end

  def customer_portal_booking_url
    return "" if business&.slug.blank? || customer_portal_booking_token.blank?

    PublicUrls.url(:customer_portal_short_booking, business, customer_portal_booking_token)
  end

  def customer_portal_profile_url
    customer_profile&.customer_portal_url.presence || customer_portal_booking_url
  end

  def google_calendar_url
    return "" unless starts_at.present? && service.present? && business.present?

    end_time = ends_at.presence || starts_at + service.duration_minutes.minutes
    params = {
      action: "TEMPLATE",
      text: google_calendar_title,
      dates: "#{google_calendar_timestamp(starts_at)}/#{google_calendar_timestamp(end_time)}",
      details: google_calendar_details,
      location: business.public_location
    }.compact_blank

    "https://calendar.google.com/calendar/u/0/r/eventedit?#{URI.encode_www_form(params)}"
  end

  def google_calendar_available_for_customer?
    google_calendar_exportable? && self.class.gmail_address?(customer_calendar_email)
  end

  def google_calendar_available_for_professional?
    google_calendar_exportable? && professional_calendar_emails.any? { |email| self.class.gmail_address?(email) }
  end

  def customer_calendar_email
    customer_profile&.normalized_email.presence || customer_profile&.email.presence || customer_email
  end

  def professional_calendar_emails
    [
      employee_membership&.email_address,
      employee_membership&.user&.email_address,
      business&.owner&.email_address
    ].compact_blank.uniq
  end

  def self.gmail_address?(value)
    domain = value.to_s.strip.downcase.split("@", 2).last
    GMAIL_DOMAINS.include?(domain)
  end

  def customer_portal_cancellable?
    return false if terminal_status?
    return false unless starts_at.future?

    Time.current <= starts_at - business.cancellation_notice_hours.hours
  end

  def customer_portal_reschedulable?
    return false if terminal_status?
    return false unless starts_at.future?

    Time.current <= starts_at - business.rescheduling_notice_hours.hours
  end

  def customer_portal_reschedule_whatsapp_url
    PhoneNumber.whatsapp_link(
      business.whatsapp_phone.presence || business.contact_phone,
      text: customer_portal_reschedule_message
    )
  end

  def to_param
    short_uuid.presence || super
  end

  private

  def broadcast_admin_appointments_refresh_after_create
    broadcast_admin_appointments_refresh
  end

  def broadcast_admin_appointments_refresh_after_confirmation
    broadcast_admin_appointments_refresh
  end

  def broadcast_admin_appointments_refresh
    Turbo::StreamsChannel.broadcast_refresh_to(*LiveStreams.admin_appointments(business))
  end

  def confirmed_in_latest_commit?
    saved_change_to_status? && confirmed?
  end

  def manual_payment_method_label
    service&.effective_payment_account&.name.presence || "Transferencia manual"
  end
    def format_currency(cents)
      "$#{ActiveSupport::NumberHelper.number_to_delimited(cents.to_i / 100, delimiter: ".")}"
    end

    def cancellation_actor(by)
      return { kind: "staff", label: by.email_address, user: by } if by.is_a?(User)

      { kind: by.to_s, label: by.to_s, user: nil }
    end

    def cancellation_user_label
      membership = canceled_by_user.employee_memberships.find do |item|
        item.business_id == business_id && item.active?
      end

      membership&.display_name.presence || canceled_by_user.name.presence || canceled_by_user.email_address
    end

    def current_add_ons
      return appointment_addons if association(:appointment_addons).loaded?

      appointment_addons.includes(:service).to_a
    end

    def manual_whatsapp_template_key
      return "booking_confirmation" if confirmed?
      return "deposit_request" if pending_deposit? || deposit_rejected?
      return "proof_request" if pending_deposit_review?
      return "booking_cancelled" if canceled?

      "public_booking_link"
    end

    def app_host
      AppUrl.host
    end

    def public_app_host
      business&.custom_domain_active? ? business.custom_domain : app_host
    end

    def app_protocol
      AppUrl.protocol
    end

    def customer_portal_reschedule_message
      [
        "Hola #{business.name}, soy #{customer_name}.",
        "Quiero reprogramar mi turno de #{service.name} del #{customer_starts_at_label}.",
        "Link de la reserva: #{customer_portal_booking_url}"
      ].join("\n")
    end

    def create_cancellation_provider_event!(by:)
      customer_initiated = CUSTOMER_CANCELLATION_ACTORS.include?(by.to_s)
      customer_portal_cancellation = by.to_s == "customer_portal"

      business.provider_events.create!(
        event_type: customer_portal_cancellation ? "customer_cancelled_booking" : "booking_cancelled",
        title: customer_initiated ? "Cliente canceló un turno" : "Turno cancelado",
        body: cancellation_provider_event_body(customer_initiated: customer_initiated),
        metadata: {
          appointment_id: id,
          customer_profile_id: customer_profile_id,
          service_id: service_id,
          canceled_by: canceled_by,
          canceled_by_user_id: canceled_by_user_id,
          cancellation_reason: cancellation_reason,
          canceled_late: canceled_late,
          action_url: customer_portal_cancellation ? customer_appointments_admin_url : admin_appointment_url,
          whatsapp_url: manual_whatsapp_url
        }.compact
      )
    end

    def cancellation_provider_event_body(customer_initiated:)
      service_name = service&.name || "el servicio"
      starts_at_text = customer_starts_at_label.presence
      reason_text = cancellation_reason.present? ? " Motivo: #{cancellation_reason}." : ""

      if customer_initiated
        "#{customer_name} canceló #{service_name}#{starts_at_text.present? ? " para #{starts_at_text}" : ""}.#{reason_text}"
      else
        "Se canceló el turno de #{customer_name} para #{service_name}#{starts_at_text.present? ? " del #{starts_at_text}" : ""}.#{reason_text}"
      end
    end

    def customer_appointments_admin_url
      return if customer_profile.blank?

      Rails.application.routes.url_helpers.edit_admin_customer_profile_url(
        customer_profile,
        anchor: "turnos",
        host: app_host,
        protocol: app_protocol
      )
    end

    def admin_appointment_url
      Rails.application.routes.url_helpers.admin_appointment_url(
        self,
        host: app_host,
        protocol: app_protocol
      )
    end

    def customer_portal_management_line
      url = customer_portal_profile_url
      return nil if url.blank?

      "También podés ver, cancelar o reprogramar tus turnos acá: #{url}"
    end

    def google_calendar_exportable?
      confirmed? && !terminal_status? && starts_at.present? && service.present? && business.present?
    end

    def google_calendar_title
      [ service.name, business.name ].compact_blank.join(" - ")
    end

    def google_calendar_timestamp(value)
      value.in_time_zone.utc.strftime("%Y%m%dT%H%M%SZ")
    end

    def google_calendar_details
      [
      "Turno en #{business.name}.",
      "Servicio: #{service.name}",
      customer_name.present? ? "Cliente: #{customer_name}" : nil,
        customer_phone.present? ? "WhatsApp: #{customer_phone}" : nil,
        customer_portal_booking_token.present? ? "Link del turno: #{customer_portal_booking_url}" : nil
      ].compact.join("\n")
    end

    def normalize_customer_phone
      self.customer_phone = PhoneNumber.normalize(customer_phone)
    end

    def ensure_short_uuid
      return if short_uuid.present?

      self.short_uuid = self.class.unique_short_uuid
    end

    def ensure_customer_portal_token
      self.customer_portal_token ||= loop do
        token = SecureRandom.urlsafe_base64(12)
        break token unless self.class.exists?(customer_portal_token: token)
      end
    end

    def self.unique_short_uuid
      loop do
        token = SecureRandom.urlsafe_base64(SHORT_UUID_BYTES)
        break token unless exists?(short_uuid: token)
      end
    end

    def ensure_deposit_review_token
      self[:deposit_review_token] ||= loop do
        token = SecureRandom.urlsafe_base64(12)
        break token unless self.class.exists?(deposit_review_token: token)
      end
    end

    def legacy_deposit_review_token
      signed_id(expires_in: 7.days, purpose: :deposit_review)
    end

    def set_ends_at
      self.ends_at ||= starts_at + service.duration_minutes.minutes if starts_at.present? && service.present?
    end

    def service_belongs_to_business
      return if service.blank? || business.blank? || service.business_id == business_id

      errors.add(:service, "no pertenece a este negocio")
    end

    def pet_belongs_to_business
      return if pet.blank? || business_id.blank? || pet.business_id == business_id

      errors.add(:pet, "no pertenece a este negocio")
    end

    def pet_belongs_to_customer_profile
      return if pet.blank?

      if customer_profile_id.blank?
        errors.add(:customer_profile, "debe estar presente cuando se asigna una mascota")
      elsif pet.customer_profile_id != customer_profile_id
        errors.add(:pet, "no pertenece a este cliente")
      end
    end

    def resource_belongs_to_business
      return if bookable_resource.blank? || business.blank? || bookable_resource.business_id == business_id

      errors.add(:bookable_resource, "no pertenece a este negocio")
    end

    def branch_belongs_to_business
      return if branch.blank? || business.blank? || branch.business_id == business_id

      errors.add(:branch, "no pertenece a este negocio")
    end

    def employee_belongs_to_business
      return if employee_membership.blank? || business.blank? || employee_membership.business_id == business_id

      errors.add(:employee_membership, "no pertenece a este negocio")
    end

    def employee_required_for_team_plan
      return if business.blank? || !business.employee_memberships.available_for_booking.exists? || employee_membership.present?

      errors.add(:employee_membership, "debe asignarse para este turno")
    end

    def deposit_receipt_file_is_valid
      return unless deposit_receipt.attached?

      unless deposit_receipt.blob.content_type.in?(DEPOSIT_RECEIPT_CONTENT_TYPES)
        errors.add(:deposit_receipt, "debe ser una imagen o PDF")
      end

      unless File.extname(deposit_receipt.filename.to_s).downcase.in?(DEPOSIT_RECEIPT_EXTENSIONS)
        errors.add(:deposit_receipt, "debe ser JPG, JPEG, PNG, WebP o PDF")
      end

      if deposit_receipt.blob.byte_size > DEPOSIT_RECEIPT_MAX_SIZE
        errors.add(:deposit_receipt, "no puede superar 5 MB")
      end
    end

    def required_resource_selected
      return if service.blank? || service.service_resources.blank? || bookable_resource.present?

      errors.add(:bookable_resource, "debe reservarse para este servicio")
    end

    def resource_enabled_for_service
      return if bookable_resource.blank? || service.blank? || service.bookable_resource_ids.blank?
      return if service.bookable_resource_ids.include?(bookable_resource_id)

      errors.add(:bookable_resource, "no está habilitado para este servicio")
    end

    def ends_after_start
      return if starts_at.blank? || ends_at.blank?

      errors.add(:ends_at, "debe ser posterior al inicio") if ends_at <= starts_at
    end

    def does_not_overlap
      return if starts_at.blank? || ends_at.blank? || business.blank?

      agenda_overlap = business.appointments.active.where.not(id: id).where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
      agenda_overlap = if employee_membership_id.present?
        agenda_overlap.where(employee_membership_id: employee_membership_id)
      else
        agenda_overlap.where(employee_membership_id: nil)
      end
      errors.add(:starts_at, "se superpone con otro turno de la misma agenda") if agenda_overlap.exists?

      return if bookable_resource_id.blank?

      availability = Resources::Availability.new(
        business: business,
        service: service,
        starts_at: starts_at,
        ends_at: ends_at,
        excluding_appointment: self
      )
      errors.add(:bookable_resource, "no tiene disponibilidad en ese horario") unless availability.available?(bookable_resource)
    end

    def employee_not_blocked
      return if starts_at.blank? || ends_at.blank? || business.blank?

      blocked = AvailabilityBlock.blocking_time?(
        business: business,
        starts_at: starts_at,
        ends_at: ends_at,
        employee_membership: employee_membership,
        online_booking: public_booking?
      )
      errors.add(:employee_membership, "no está disponible en ese horario") if blocked
    end

    def waitlist_relevant_cancellation?
      saved_change_to_status? && canceled? && starts_at.future?
    end

    def notify_waitlist_for_cancellation
      WaitlistNotificationService.call(self)
    end

    def self.label_for(value, labels)
      value = value.to_s
      labels.fetch(value, value.tr("_", " ").capitalize)
    end
end
