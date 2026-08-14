require "uri"

class AppointmentPayment < ApplicationRecord
  PROVIDERS = %w[mercado_pago].freeze
  STATUSES = %w[pending approved rejected cancelled refunded failed].freeze

  belongs_to :business
  belongs_to :appointment

  before_validation :ensure_external_reference, on: :create

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, :external_reference, presence: true
  validates :external_reference, uniqueness: true
  validate :appointment_belongs_to_business

  def appointment_ids
    ids = Array(metadata.to_h["appointment_ids"]).map(&:to_i).select(&:positive?)
    ids.presence || [ appointment_id ]
  end

  def appointments
    business.appointments.where(id: appointment_ids)
  end

  def checkout_url
    return sandbox_init_point.presence || init_point.presence if MercadoPago::Credentials.test?

    return init_point if production_checkout_url?(init_point)

    raise ArgumentError, "Mercado Pago no devolvió un enlace de checkout productivo. Reconectá la cuenta de cobro."
  end

  def approved?
    status == "approved"
  end

  def pending?
    status == "pending"
  end

  def mark_approved!(payload:)
    update!(
      status: "approved",
      paid_at: Time.current,
      failed_at: nil,
      provider_payment_id: payload["id"].to_s.presence || provider_payment_id,
      provider_merchant_order_id: payload.dig("order", "id").to_s.presence || provider_merchant_order_id,
      raw_payload: payload
    )
  end

  def mark_failed!(status:, payload:)
    update!(
      status: status.to_s.presence_in(STATUSES) || "failed",
      failed_at: Time.current,
      raw_payload: payload
    )
  end

  private
    def production_checkout_url?(url)
      host = URI.parse(url.to_s).host.to_s.downcase
      url.present? && host.present? && !host.start_with?("sandbox.")
    rescue URI::InvalidURIError
      false
    end

    def ensure_external_reference
      self.external_reference ||= "mp-#{SecureRandom.urlsafe_base64(18)}"
    end

    def appointment_belongs_to_business
      return if appointment.blank? || business.blank? || appointment.business_id == business_id

      errors.add(:appointment, "no pertenece a este negocio")
    end
end
