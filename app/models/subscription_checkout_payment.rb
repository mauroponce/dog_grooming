require "uri"

class SubscriptionCheckoutPayment < ApplicationRecord
  STATUSES = %w[pending approved rejected cancelled failed].freeze

  belongs_to :business
  belongs_to :subscription_invoice

  scope :pending, -> { where(status: "pending") }

  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, :external_reference, presence: true
  validates :external_reference, uniqueness: true
  validates :provider_payment_id, uniqueness: true, allow_blank: true
  validate :invoice_belongs_to_business

  def active?
    pending? && (expires_at.blank? || expires_at.future?)
  end

  def pending? = status == "pending"
  def approved? = status == "approved"

  def checkout_url
    return sandbox_init_point.presence || init_point.presence if MercadoPago::Credentials.test?
    return init_point if URI.parse(init_point.to_s).host.to_s.present? && !URI.parse(init_point.to_s).host.to_s.start_with?("sandbox.")

    raise ArgumentError, "Mercado Pago no devolvió un checkout productivo."
  rescue URI::InvalidURIError
    raise ArgumentError, "Mercado Pago no devolvió un checkout productivo."
  end

  def mark_approved!(payload:)
    update!(status: "approved", paid_at: Time.current, failed_at: nil, provider_payment_id: payload["id"].to_s, raw_payload: payload)
  end

  def mark_failed!(status:, payload:)
    update!(status: status.to_s.presence_in(STATUSES) || "failed", failed_at: Time.current, raw_payload: payload)
  end

  private
    def invoice_belongs_to_business
      errors.add(:subscription_invoice, "no pertenece a este negocio") if subscription_invoice.present? && subscription_invoice.business_id != business_id
    end
end
