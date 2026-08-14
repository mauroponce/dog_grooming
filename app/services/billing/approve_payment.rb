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
      invoice.transaction do
        proof&.update!(status: "approved", reviewed_at: Time.current, reviewed_by: reviewer)
        invoice.update!(status: "paid", paid_at: Time.current)
        invoice.subscription.update!(
          status: "active",
          subscribed_at: invoice.subscription.subscribed_at || Time.current,
          last_payment_at: Time.current,
          expires_at: invoice.period_end.end_of_day,
          paid_until: invoice.period_end,
          current_period_start: invoice.period_start,
          current_period_end: invoice.period_end,
          next_due_on: invoice.period_end,
          grace_ends_on: invoice.period_end + 15.days,
          restricted_at: nil,
          suspended_at: nil
        )
        invoice.business.update!(disabled_at: nil) if invoice.business.disabled_at.present?
        complete_tasks!
      end

      BillingMailer.payment_approved(invoice).deliver_later unless manual_without_customer_notice?
      invoice
    end

    private
      attr_reader :invoice, :reviewer, :manual

      def proof
        @proof ||= invoice.current_proof
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
