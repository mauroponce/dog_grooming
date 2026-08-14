class BillingTransferAccount < ApplicationRecord
  SINGLETON_KEY = "primary"

  normalizes :transfer_alias, :cbu, :account_holder, :tax_id, with: ->(value) { value.to_s.strip.presence }

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

  private
    def transfer_destination_present
      return if configured?

      errors.add(:base, "Completá al menos el alias o CBU/CVU de la cuenta receptora.")
    end
end
