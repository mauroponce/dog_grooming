class CustomerProfile < ApplicationRecord
  CUSTOMER_PORTAL_TOKEN_BYTES = 24
  CUSTOMER_PORTAL_SHORT_TOKEN_BYTES = 9
  CUSTOMER_PHOTO_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp].freeze
  CUSTOMER_PHOTO_MAX_SIZE = 10.megabytes
  CUSTOMER_PHOTO_LIMIT = 6

  GENDER_OPTIONS = {
    "masculino" => "Masculino",
    "femenino" => "Femenino"
  }.freeze

  belongs_to :business, counter_cache: true
  has_many :appointments, dependent: :nullify
  has_many :pets, dependent: :destroy, inverse_of: :customer_profile
  accepts_nested_attributes_for :pets, reject_if: :all_blank
  has_many :client_notes, dependent: :destroy
  has_many :booking_notes, dependent: :destroy
  has_many :booking_attachments, dependent: :destroy
  has_many :customer_reminders, dependent: :destroy
  has_many :sales_opportunities, dependent: :nullify
  has_many :sales_campaign_recipients, dependent: :destroy
  has_many :customer_packs, dependent: :destroy
  has_many :booking_intents, dependent: :nullify
  has_many :service_form_responses, dependent: :destroy
  has_many :referrals_made, class_name: "Referral", foreign_key: :referrer_customer_id, dependent: :destroy, inverse_of: :referrer_customer
  has_many :referrals_received, class_name: "Referral", foreign_key: :referred_customer_id, dependent: :nullify, inverse_of: :referred_customer
  has_many :customer_portal_access_tokens, dependent: :destroy
  has_many_attached :customer_photos

  scope :kept, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  default_scope { kept }

  before_validation :normalize_profile_fields
  before_validation :normalize_phone
  before_validation :normalize_email
  before_validation :ensure_customer_portal_token
  before_validation :ensure_customer_portal_short_token

  validate :phone_must_be_present
  validates :normalized_phone, uniqueness: { scope: :business_id }, allow_blank: true
  validates :gender, inclusion: { in: GENDER_OPTIONS.keys }, allow_blank: true
  validates :customer_portal_token, presence: true, uniqueness: true
  validates :customer_portal_short_token, presence: true, uniqueness: true

  def blocked?
    blocked_at.present?
  end

  def deleted?
    deleted_at.present?
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def block!(reason)
    update!(blocked_at: Time.current, blocked_reason: reason.presence || "Bloqueado por el profesional")
  end

  def unblock!
    update!(blocked_at: nil, blocked_reason: nil)
  end

  def gender_label
    GENDER_OPTIONS[gender]
  end

  def customer_portal_url
    PublicUrls.url(
      :customer_portal_profile_access,
      business,
      customer_portal_short_token.presence || customer_portal_token
    )
  end

  def register_cancellation!(appointment)
    if appointment.canceled_late?
      increment!(:total_cancellations_count)
      increment!(:consecutive_late_cancellations_count)
      update!(last_late_cancellation_at: Time.current)
      create_late_cancellation_alert! if consecutive_late_cancellations_count >= 3
    else
      update!(
        total_cancellations_count: total_cancellations_count + 1,
        consecutive_late_cancellations_count: 0
      )
    end
  end

  def register_no_show!(appointment)
    update!(
      no_show_count: no_show_count + 1,
      last_no_show_at: Time.current
    )
  end

  private
    def normalize_profile_fields
      self.first_name = first_name.to_s.squish.presence
      self.last_name = last_name.to_s.squish.presence
      self.name = [ first_name, last_name ].compact_blank.join(" ").presence || name.to_s.squish.presence
      self.phone = phone.to_s.strip.presence
      self.gender = gender.to_s.strip.downcase.presence
    end

    def phone_must_be_present
      errors.add(:base, "Ingresá teléfono") if phone.blank?
    end

    def normalize_phone
      self.normalized_phone = PhoneNumber.normalize(phone)
    end

    def normalize_email
      self.email = email.to_s.strip.downcase.presence
      self.normalized_email = email
    end

    def ensure_customer_portal_token
      return if customer_portal_token.present?

      self.customer_portal_token = self.class.unique_customer_portal_token
    end

    def ensure_customer_portal_short_token
      return if customer_portal_short_token.present?

      self.customer_portal_short_token = self.class.unique_customer_portal_short_token
    end

    def self.unique_customer_portal_token
      loop do
        token = SecureRandom.urlsafe_base64(CUSTOMER_PORTAL_TOKEN_BYTES)
        break token unless exists?(customer_portal_token: token)
      end
    end

    def self.unique_customer_portal_short_token
      loop do
        token = SecureRandom.urlsafe_base64(CUSTOMER_PORTAL_SHORT_TOKEN_BYTES)
        break token unless exists?(customer_portal_short_token: token)
      end
    end

    def create_late_cancellation_alert!
      business.provider_events.create!(
        event_type: "customer_late_cancellation_alert",
        title: "Cliente con cancelaciones tardías recurrentes",
        body: "#{name.presence || phone} acumula #{consecutive_late_cancellations_count} cancelaciones sobre la hora.",
        metadata: { customer_profile_id: id, phone: phone }
      )
    end
end
