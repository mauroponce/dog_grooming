class User < ApplicationRecord
  include PurgesReplacedAttachedBlobs

  PROFILE_PHOTO_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp].freeze
  PROFILE_PHOTO_MAX_SIZE = 5.megabytes

  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_one :business, foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :employee_memberships, dependent: :destroy
  has_many :employee_businesses, through: :employee_memberships, source: :business
  has_many :assigned_customer_reminders, class_name: "CustomerReminder", foreign_key: :assigned_to_id, dependent: :nullify
  has_many :completed_appointments, class_name: "Appointment", foreign_key: :completed_by_id, dependent: :nullify
  has_many :canceled_appointments, class_name: "Appointment", foreign_key: :canceled_by_user_id, dependent: :nullify
  has_many :created_booking_notes, class_name: "BookingNote", foreign_key: :created_by_id, dependent: :restrict_with_error
  has_many :uploaded_booking_attachments, class_name: "BookingAttachment", foreign_key: :uploaded_by_id, dependent: :restrict_with_error
  has_many :created_sales_campaigns, class_name: "SalesCampaign", foreign_key: :created_by_id, dependent: :nullify
  has_many :created_campaign_links, class_name: "CampaignLink", foreign_key: :created_by_id, dependent: :nullify
  has_many :created_pack_sessions, class_name: "PackSession", foreign_key: :created_by_id, dependent: :nullify
  has_many :created_gift_cards, class_name: "GiftCard", foreign_key: :created_by_id, dependent: :nullify
  has_one_attached :profile_photo
  purge_replaced_attached_blobs_for :profile_photo

  enum :role, { admin: 0, super_admin: 1, employee: 2 }

  before_validation :normalize_profile_fields

  validates :email_address, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :profile_photo_is_valid

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def disabled?
    disabled_at.present?
  end

  def primary_business
    return business if admin? || super_admin?

    employee_memberships.active.includes(:business).first&.business
  end

  def employee_membership_for(business)
    return if business.blank?

    employee_memberships.active.find_by(business: business)
  end

  def magic_login_token(expires_in: 20.minutes)
    signed_id(expires_in:, purpose: :staff_magic_login)
  end

  private
    def normalize_profile_fields
      self.name = name.to_s.squish.presence if has_attribute?(:name)
      self.phone = phone.present? ? PhoneNormalizer.normalize(phone) : nil if has_attribute?(:phone)
    end

    def sync_owner_membership_name!
      employee_memberships.find_each do |membership|
        next unless membership.owner_profile?

        membership.update!(name: name)
      end
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
end
