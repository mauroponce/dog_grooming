module Billing
  class ApprovePayment
    def self.call(...)
      new(...).call
    end

    def initialize(invoice:, reviewer:, manual: false)
      @invoice = invoice
      @reviewer = reviewer
      @manual = manual
    end

    def call
      invoice.with_lock do
        return invoice if invoice.paid?

        invoice.transaction do
          period_start, period_end = approved_period
          proof&.update!(status: "approved", reviewed_at: Time.current, reviewed_by: reviewer)
          invoice.update!(status: "paid", paid_at: Time.current, period_start: period_start, period_end: period_end)
          invoice.subscription.update!(
            status: "active",
            subscribed_at: invoice.subscription.subscribed_at || Time.current,
            last_payment_at: Time.current,
            expires_at: period_end.end_of_day,
            paid_until: period_end,
            current_period_start: period_start,
            current_period_end: period_end,
            next_due_on: period_end,
            grace_ends_on: period_end + Business::BILLING_GRACE_DAYS.days,
            restricted_at: nil,
            suspended_at: nil
          )
          invoice.business.update!(disabled_at: nil) if invoice.business.disabled_at.present?
          complete_tasks!
        end
      end

      BillingMailer.payment_approved(invoice).deliver_later unless manual_without_customer_notice?
      invoice
    end

    private
      attr_reader :invoice, :reviewer, :manual

      def proof
        @proof ||= invoice.current_proof
      end

      def approved_period
        subscription = invoice.subscription
        starts_on = if subscription.active? && subscription.paid_until.present? && subscription.paid_until >= Time.zone.today
          subscription.paid_until
        else
          Time.zone.today
        end
        [ starts_on, starts_on + 30.days ]
      end

      def complete_tasks!
        SuperAdminTask.pending.where(record: invoice).find_each(&:complete!)
        SuperAdminTask.pending.where(record: proof).find_each(&:complete!) if proof.present?
      end

      def manual_without_customer_notice?
        false
      end
  end
end
