class SubscriptionInvoice < ApplicationRecord
  STATUSES = %w[open pending_review paid rejected overdue void].freeze

  belongs_to :business
  belongs_to :subscription
  has_many :subscription_payment_proofs, dependent: :destroy
  has_many :subscription_checkout_payments, dependent: :destroy
  has_many :billing_reminders, dependent: :destroy

  validates :period_start, :period_end, :amount_cents, :due_on, :reference_code, :status, presence: true
  validates :plan_selected, inclusion: { in: Subscription::PLANS.keys }
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :billing_period_months, numericality: { only_integer: true, greater_than: 0 }
  validates :reference_code, uniqueness: true
  validate :period_end_after_start
  validate :records_belong_to_business

  scope :open_for_review, -> { where(status: %w[open pending_review rejected overdue]) }
  scope :pending_review, -> { where(status: "pending_review") }
  scope :overdue, -> { where(status: %w[overdue rejected]) }
  scope :recent, -> { order(due_on: :desc, created_at: :desc) }

  def current_proof
    subscription_payment_proofs.where(status: %w[pending_review approved rejected]).order(created_at: :desc).first
  end

  def pending_review?
    status == "pending_review"
  end

  def paid?
    status == "paid"
  end

  def rejected?
    status == "rejected"
  end

  def overdue?
    status == "overdue" || (due_on.present? && due_on < Time.zone.today && !paid? && !pending_review?)
  end

  def due_today?
    due_on == Time.zone.today
  end

  def days_overdue
    return 0 if due_on.blank? || due_on >= Time.zone.today

    (Time.zone.today - due_on).to_i
  end

  def amount_label
    "$#{(amount_cents.to_i / 100).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
  end

  private
    def period_end_after_start
      return if period_start.blank? || period_end.blank? || period_end > period_start

      errors.add(:period_end, "debe ser posterior al inicio")
    end

    def records_belong_to_business
      errors.add(:subscription, "no pertenece al negocio") if subscription.present? && subscription.business_id != business_id
    end
end
