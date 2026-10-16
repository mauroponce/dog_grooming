class GiftCard < ApplicationRecord
  STATUSES = %w[draft pending_payment paid redeemed expired cancelled].freeze

  belongs_to :business
  belongs_to :service, optional: true
  belongs_to :redeemed_booking, class_name: "Appointment", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  before_validation :normalize_phones
  before_validation :ensure_code

  validates :code, :title, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :code, uniqueness: { scope: :business_id }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :records_belong_to_business

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %w[draft pending_payment paid]) }
  scope :paid, -> { where(status: "paid") }

  STATUSES.each do |value|
    define_method("#{value}?") { status == value }
  end

  def mark_paid!
    update!(status: "paid", purchased_at: Time.current)
  end

  def redeem!(appointment: nil)
    if redeemed?
      errors.add(:base, "La gift card ya fue usada")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(status: "redeemed", redeemed_booking: appointment, redeemed_at: Time.current)
  end

  def cancel!
    update!(status: "cancelled")
  end

  def display_amount
    return service&.display_price if amount_cents.blank? || amount_cents.zero?

    "$#{(amount_cents.to_i / 100).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
  end

  def delivery_message
    lines = [
      "Hola #{recipient_name.presence || "!"}",
      "Te regalaron una gift card de #{business.name}: #{title}.",
      "Código: #{code}",
      "Valor: #{display_amount}"
    ]
    lines << "Mensaje: #{message}" if message.present?
    lines << "Para reservar, escribinos o entrá a #{business.public_url}."
    lines.join("\n")
  end

  private
    def normalize_phones
      self.buyer_phone_e164 = PhoneNumber.normalize(buyer_phone_e164) if buyer_phone_e164.present?
      self.recipient_phone_e164 = PhoneNumber.normalize(recipient_phone_e164) if recipient_phone_e164.present?
    end

    def ensure_code
      self.code = generated_code if code.blank? && business.present?
      self.code = code.to_s.strip.upcase
    end

    def generated_code
      prefix = business.slug.to_s.split("-").first.to_s.upcase.first(4).presence || "HT"
      loop do
        candidate = "#{prefix}-#{SecureRandom.hex(2).upcase}"
        break candidate unless business.gift_cards.exists?(code: candidate)
      end
    end

    def records_belong_to_business
      errors.add(:service, "no pertenece al negocio") if service.present? && service.business_id != business_id
      errors.add(:redeemed_booking, "no pertenece al negocio") if redeemed_booking.present? && redeemed_booking.business_id != business_id
      return if created_by.blank? || business.blank?
      return if created_by.admin? && created_by.business&.id == business_id
      return if created_by.employee_membership_for(business).present?

      errors.add(:created_by, "no pertenece al negocio")
    end
end
