class PaymentAccount < ApplicationRecord
  belongs_to :business
  has_many :services, dependent: :nullify

  validates :name, :details, presence: true
  validates :primary_account, uniqueness: { scope: :business_id }, if: :primary_account?
  validate :primary_account_is_active

  normalizes :name, with: ->(value) { value.to_s.squish.presence }
  normalizes :details, with: ->(value) { value.to_s.strip.presence }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(primary_account: :desc, created_at: :asc, id: :asc) }

  def self.primary_for(business)
    business.payment_accounts.active.find_by(primary_account: true) ||
      business.payment_accounts.active.ordered.first
  end

  def display_name
    primary_account? ? "#{name} (principal)" : name
  end

  def payment_reference
    detail_lines = details.to_s.lines.map(&:strip).compact_blank
    detail_lines.each_with_index do |line, index|
      normalized = I18n.transliterate(line).downcase
      next unless normalized.match?(/\A(alias|cbu|cvu|link de pago)\b/)

      return line if line.include?(":") && line.split(":", 2).last.to_s.strip.present?

      next_value = detail_lines[index + 1]
      return "#{line}: #{next_value}" if next_value.present?
      return line
    end

    detail_lines.first || name
  end

  private
    def primary_account_is_active
      return unless primary_account? && !active?

      errors.add(:primary_account, "debe estar activa")
    end
end
