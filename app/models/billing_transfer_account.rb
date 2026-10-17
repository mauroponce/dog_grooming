class BillingTransferAccount < ApplicationRecord
  SINGLETON_KEY = "primary"

  normalizes :transfer_alias, :cbu, :account_holder, :tax_id, with: ->(value) { value.to_s.strip.presence }
  has_one_attached :account_proof

  ACCOUNT_PROOF_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp application/pdf].freeze
  ACCOUNT_PROOF_MAX_SIZE = 5.megabytes

  validates :singleton_key, presence: true, uniqueness: true
  validate :transfer_destination_present

  def self.current
    find_or_initialize_by(singleton_key: SINGLETON_KEY).tap do |account|
      account.transfer_alias ||= ENV["DOG_GROOMING_BILLING_ALIAS"].presence
      account.cbu ||= ENV["DOG_GROOMING_BILLING_CBU"].presence
      account.account_holder ||= ENV["DOG_GROOMING_BILLING_HOLDER"].presence
      account.tax_id ||= ENV["DOG_GROOMING_BILLING_TAX_ID"].presence
    end
  end

  def configured?
    transfer_alias.present? || cbu.present?
  end

  def validate_account_proof!(file)
    return if file.blank?

    Assets::PrivateAttachmentValidator.validate!(file, content_types: ACCOUNT_PROOF_CONTENT_TYPES, max_size: ACCOUNT_PROOF_MAX_SIZE)
  end

  private
    def transfer_destination_present
      return if configured?

      errors.add(:base, "Completá al menos el alias o CBU/CVU de la cuenta receptora.")
    end
end
