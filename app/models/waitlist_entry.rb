class WaitlistEntry < ApplicationRecord
  STATUSES = %w[waiting offered booked dismissed expired].freeze
  LEGACY_STATUS_MAP = {
    "pending" => "waiting",
    "notified" => "offered",
    "completed" => "booked"
  }.freeze
  SOURCES = %w[public_page admin chatbot].freeze
  TIME_PRESETS = {
    "any" => { "label" => "En cualquier momento", "start_time" => "00:00", "end_time" => "23:55" },
    "morning" => { "label" => "Mañana", "start_time" => "06:00", "end_time" => "12:00" },
    "afternoon" => { "label" => "Tarde", "start_time" => "12:00", "end_time" => "18:00" },
    "night" => { "label" => "Noche", "start_time" => "18:00", "end_time" => "23:55" }
  }.freeze

  belongs_to :center, class_name: "Business", foreign_key: :center_id, inverse_of: :waitlist_entries
  belongs_to :service
  belongs_to :customer_profile, optional: true
  belongs_to :employee_membership, optional: true
  belongs_to :released_appointment, class_name: "Appointment", optional: true

  before_validation :normalize_legacy_status
  before_validation :normalize_phone
  before_validation :assign_customer_profile
  after_create_commit :notify_provider_later

  validates :client_name, :client_phone, :desired_date, :status, :source, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validate :service_belongs_to_center
  validate :employee_belongs_to_center

  scope :pending, -> { where(status: "waiting") }
  scope :notified, -> { where(status: "offered") }
  scope :visible, -> { where(status: %w[waiting offered]) }
  scope :compatible_with, ->(service, starts_at) { where(service: service, desired_date: starts_at.to_date) }

  def self.normalize_time_window(value)
    attrs = if value.respond_to?(:to_unsafe_h)
      value.to_unsafe_h
    elsif value.respond_to?(:to_h) && !value.is_a?(String)
      value.to_h
    else
      { "period" => value.to_s }
    end

    attrs = attrs.stringify_keys
    preset = TIME_PRESETS[preset_key_for(attrs["period"].presence || attrs["label"])]
    label = attrs["label"].presence || preset&.fetch("label", nil)
    start_time = attrs["start_time"].presence || attrs["start"].presence || preset&.fetch("start_time", nil)
    end_time = attrs["end_time"].presence || attrs["end"].presence || preset&.fetch("end_time", nil)
    period = attrs["period"].presence || TIME_PRESETS.find { |_key, item| item["label"] == label }&.first || "custom"

    return nil unless valid_time_label?(start_time) && valid_time_label?(end_time)

    {
      "period" => period,
      "label" => label.presence || "#{start_time} a #{end_time}",
      "start_time" => start_time,
      "end_time" => end_time
    }
  end

  def self.time_window_covers?(windows, starts_at)
    normalized = Array(windows).filter_map { |window| normalize_time_window(window) }
    return true if normalized.blank?

    minutes = minutes_for(starts_at.in_time_zone.strftime("%H:%M"))
    normalized.any? do |window|
      start_minutes = minutes_for(window.fetch("start_time"))
      end_minutes = minutes_for(window.fetch("end_time"))

      if start_minutes <= end_minutes
        minutes >= start_minutes && minutes < end_minutes
      else
        minutes >= start_minutes || minutes < end_minutes
      end
    end
  end

  def self.time_window_label(window)
    normalized = normalize_time_window(window)
    return "En cualquier momento" if normalized.blank?

    if normalized["period"].present? && TIME_PRESETS[normalized["period"]]&.slice("start_time", "end_time") == normalized.slice("start_time", "end_time")
      normalized.fetch("label")
    else
      "#{normalized.fetch("start_time")} a #{normalized.fetch("end_time")}"
    end
  end

  def self.preset_key_for(value)
    normalized = value.to_s.strip.downcase.parameterize
    {
      "en-cualquier-momento" => "any",
      "cualquier-momento" => "any",
      "any" => "any",
      "manana" => "morning",
      "morning" => "morning",
      "tarde" => "afternoon",
      "afternoon" => "afternoon",
      "noche" => "night",
      "night" => "night"
    }.fetch(normalized, normalized)
  end

  def self.valid_time_label?(value)
    value.to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
  end

  def self.minutes_for(value)
    hours, minutes = value.to_s.split(":").map(&:to_i)
    (hours * 60) + minutes
  end

  STATUSES.each do |value|
    define_method("#{value}?") { status == value }
  end

  def notification_token
    signed_id(expires_in: 15.minutes, purpose: :waitlist_confirmation)
  end

  def confirmation_url
    Rails.application.routes.url_helpers.waitlist_confirmation_url(
      token: token_seguro.presence || notification_token,
      host: AppUrl.host,
      protocol: AppUrl.protocol
    )
  end

  def whatsapp_message
    WhatsApp::MessageBuilder.new(
      business: center,
      template_key: "waitlist_offer",
      customer: customer_profile,
      service: service,
      professional: employee_membership,
      waitlist_entry: self
    ).message
  end

  def whatsapp_url
    WhatsApp::MessageBuilder.new(
      business: center,
      template_key: "waitlist_offer",
      customer: customer_profile,
      service: service,
      professional: employee_membership,
      waitlist_entry: self
    ).url(phone: client_phone)
  end

  def preferred_time_window_labels
    Array(preferred_time_windows).map { |window| self.class.time_window_label(window) }.presence || [ "En cualquier momento" ]
  end

  def matches_released_slot?(starts_at)
    desired_date == starts_at.to_date && self.class.time_window_covers?(preferred_time_windows, starts_at)
  end

  def released_starts_at_label
    CustomerDateFormatter.appointment_label(released_starts_at)
  end

  def expired_notification?
    expires_at.present? && expires_at.past?
  end

  def waiting?
    status == "waiting"
  end

  def offered?
    status == "offered"
  end

  def booked?
    status == "booked"
  end

  def dismiss!
    update!(status: "dismissed", dismissed_at: Time.current)
  end

  private
    def normalize_phone
      self.client_phone = PhoneNumber.normalize(client_phone)
      self.phone_e164 = client_phone
    end

    def normalize_legacy_status
      self.status = LEGACY_STATUS_MAP.fetch(status, status)
    end

    def assign_customer_profile
      return if center.blank? || client_phone.blank?

      self.customer_profile = Customers::UpsertProfile.call(
        business: center,
        name: client_name,
        phone: client_phone,
        email: email
      )
    end

    def service_belongs_to_center
      return if service.blank? || center.blank? || service.business_id == center_id

      errors.add(:service, "no pertenece a este centro")
    end

    def employee_belongs_to_center
      return if employee_membership.blank? || center.blank? || employee_membership.business_id == center_id

      errors.add(:employee_membership, "no pertenece a este centro")
    end

    def notify_provider_later
      center.provider_events.create!(
        event_type: "waitlist_entry_created",
        title: "Nueva persona en lista de espera",
        body: "#{client_name} espera un turno para #{service.name} el #{CustomerDateFormatter.date_label(desired_date)}.",
        metadata: {
          waitlist_entry_id: id,
          service_id: service_id,
          desired_date: desired_date.iso8601,
          action_url: Rails.application.routes.url_helpers.admin_calendar_url(
            waitlist: "1",
            service_id: service_id,
            desired_date: desired_date.iso8601,
            host: AppUrl.host,
            protocol: AppUrl.protocol
          )
        }
      )
      BusinessMailer.new_waitlist_entry(self).deliver_later if center.email_new_waitlist_entry? && center.owner.email_address.present?
    end
end
