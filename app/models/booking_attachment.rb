class BookingAttachment < ApplicationRecord
  include PurgesReplacedAttachedBlobs

  ATTACHMENT_TYPES = %w[deposit_proof client_reference_photo post_appointment_photo marketing_approved_photo].freeze
  VISIBILITIES = %w[internal marketing_approved].freeze
  MARKETING_CONSENT_STATUSES = %w[not_requested requested approved rejected].freeze
  PHOTO_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp image/heic image/heif].freeze
  PHOTO_MAX_SIZE = 5.megabytes

  belongs_to :business
  belongs_to :appointment
  belongs_to :customer_profile
  belongs_to :uploaded_by, class_name: "User"
  has_one_attached :file
  purge_replaced_attached_blobs_for :file

  validates :attachment_type, inclusion: { in: ATTACHMENT_TYPES }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :marketing_consent_status, inclusion: { in: MARKETING_CONSENT_STATUSES }
  validate :customer_belongs_to_business
  validate :appointment_belongs_to_business
  validate :uploader_belongs_to_business
  validate :file_is_valid

  scope :internal, -> { where(visibility: "internal") }
  scope :post_appointment_photos, -> { where(attachment_type: "post_appointment_photo") }
  scope :marketing_approved, -> { where(marketing_consent_status: "approved") }
  scope :recent_first, -> { order(created_at: :desc) }

  def self.validate_photo_upload!(upload)
    content_type = upload.respond_to?(:content_type) ? upload.content_type.to_s : ""
    size = upload.respond_to?(:size) ? upload.size.to_i : upload.try(:tempfile).try(:size).to_i

    raise ActiveRecord::RecordInvalid.new(invalid_record("debe ser JPG, PNG, WebP o HEIC")) unless content_type.in?(PHOTO_CONTENT_TYPES)
    raise ActiveRecord::RecordInvalid.new(invalid_record("no puede superar 5 MB")) if size > PHOTO_MAX_SIZE
  end

  def post_appointment_photo?
    attachment_type == "post_appointment_photo"
  end

  def request_marketing_consent!
    update!(marketing_consent_status: "requested", marketing_consent_requested_at: Time.current)
  end

  def approve_marketing_consent!(source: "manual")
    update!(
      marketing_consent_status: "approved",
      marketing_consent_approved_at: Time.current,
      marketing_consent_source: source,
      visibility: "marketing_approved"
    )
  end

  def reject_marketing_consent!
    update!(marketing_consent_status: "rejected")
  end

  private
    def self.invalid_record(message)
      record = new
      record.errors.add(:base, message)
      record
    end

    def customer_belongs_to_business
      return if customer_profile.blank? || business.blank? || customer_profile.business_id == business_id

      errors.add(:customer_profile, "no pertenece a este negocio")
    end

    def appointment_belongs_to_business
      return if appointment.blank? || business.blank? || appointment.business_id == business_id

      errors.add(:appointment, "no pertenece a este negocio")
    end

    def uploader_belongs_to_business
      return if uploaded_by.blank? || business.blank?
      return if uploaded_by.admin? && uploaded_by.business&.id == business_id
      return if uploaded_by.employee_membership_for(business).present?

      errors.add(:uploaded_by, "no pertenece a este negocio")
    end

    def file_is_valid
      return unless file.attached?

      unless file.blob.content_type.in?(PHOTO_CONTENT_TYPES)
        errors.add(:file, "debe ser JPG, PNG, WebP o HEIC")
      end

      if file.blob.byte_size > PHOTO_MAX_SIZE
        errors.add(:file, "no puede superar 5 MB")
      end
    end
end
