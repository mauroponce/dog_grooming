class Subscription < ApplicationRecord
  ACTIVE_STATUSES = %w[active authorized payment_due pending_review overdue restricted].freeze
  PAID_STATUSES = %w[active authorized].freeze
  STATUSES = %w[
    trialing active authorized payment_due pending_review overdue restricted suspended cancelled canceled
    payment_pending payment_under_review past_due pending expired failed
  ].freeze

  belongs_to :business
  has_many :subscription_invoices, dependent: :destroy
  has_many :subscription_payment_proofs, through: :subscription_invoices

  validates :external_reference, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: %w[manual mercado_pago] }

  before_validation :set_billing_defaults

  def active?
    return provider_status == "authorized" && paid_until.present? && paid_until >= Time.zone.today && !cancelled? && !suspended? if mercado_pago?

    ACTIVE_STATUSES.include?(normalized_status) && !suspended? && !cancelled?
  end

  def paid?
    return active? if mercado_pago?

    PAID_STATUSES.include?(normalized_status) && (paid_until.blank? || paid_until >= Time.zone.today)
  end

  def mercado_pago?
    provider == "mercado_pago"
  end

  def trialing?
    normalized_status == "trialing"
  end

  def pending_review?
    normalized_status == "pending_review"
  end

  def overdue?
    normalized_status == "overdue"
  end

  def restricted?
    normalized_status == "restricted"
  end

  def suspended?
    normalized_status == "suspended"
  end

  def cancelled?
    normalized_status == "cancelled"
  end

  def payment_due?
    normalized_status == "payment_due"
  end

  def normalized_status
    {
      "authorized" => "active",
      "payment_under_review" => "pending_review",
      "payment_pending" => "payment_due",
      "past_due" => "overdue",
      "pending" => "overdue",
      "expired" => "overdue",
      "failed" => "overdue",
      "canceled" => "cancelled"
    }.fetch(status, status)
  end

  def current_invoice
    subscription_invoices.where(status: %w[open pending_review rejected overdue]).order(due_on: :asc, created_at: :desc).first
  end

  def latest_invoice
    subscription_invoices.order(created_at: :desc).first
  end

  def mark_authorized!(payload = {})
    update!(
      status: "active",
      subscribed_at: subscribed_at || Time.current,
      last_payment_at: Time.current,
      expires_at: 1.month.from_now,
      raw_payload: payload.presence || raw_payload
    )
  end

  def mark_pending!(payload = {})
    update!(status: "pending_review", raw_payload: payload.presence || raw_payload)
  end

  def mark_canceled!(payload = {})
    update!(status: "cancelled", cancelled_at: Time.current, raw_payload: payload.presence || raw_payload)
  end

  private
    def set_billing_defaults
      details = Business::SUBSCRIPTION_DETAILS
      self.amount_cents ||= details.fetch(:monthly_amount_cents)
      self.billing_period_months ||= 1
      self.trial_started_on ||= business&.trial_started_at&.to_date
      self.trial_ends_on ||= business&.trial_ends_at&.to_date
      self.next_due_on ||= paid_until || trial_ends_on || expires_at&.to_date
      self.grace_ends_on ||= next_due_on + 15.days if next_due_on.present?
    end
end
