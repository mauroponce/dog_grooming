module Billing
  class ApproveCheckoutPayment
    def self.call(...) = new(...).call

    def initialize(payment:, payload:)
      @payment = payment
      @payload = payload
    end

    def call
      payment.with_lock do
        return payment if payment.approved?

        invoice = payment.subscription_invoice
        invoice.with_lock do
          payment.mark_approved!(payload: payload)
          return payment if invoice.paid?

          invoice.update!(status: "paid", paid_at: Time.current)
          invoice.subscription.update!(
            status: "active", subscribed_at: invoice.subscription.subscribed_at || Time.current,
            last_payment_at: Time.current, expires_at: invoice.period_end.end_of_day,
            paid_until: invoice.period_end, current_period_start: invoice.period_start,
            current_period_end: invoice.period_end, next_due_on: invoice.period_end,
            grace_ends_on: invoice.period_end + Business::BILLING_GRACE_DAYS.days, restricted_at: nil, suspended_at: nil
          )
          invoice.business.update!(disabled_at: nil) if invoice.business.disabled_at.present?
        end
      end
      BillingMailer.payment_approved(payment.subscription_invoice).deliver_later
      payment
    end

    private
      attr_reader :payment, :payload
  end
end
