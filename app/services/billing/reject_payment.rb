module Billing
  class RejectPayment
    def self.call(...)
      new(...).call
    end

    def initialize(invoice:, reviewer:, reason:)
      @invoice = invoice
      @reviewer = reviewer
      @reason = reason.to_s.strip.presence || "No pudimos validar el comprobante."
    end

    def call
      invoice.transaction do
        proof&.update!(
          status: "rejected",
          reviewed_at: Time.current,
          reviewed_by: reviewer,
          rejection_reason: reason
        )
        invoice.update!(status: invoice.due_on < Time.zone.today ? "overdue" : "rejected", notes: reason)
        invoice.subscription.update!(status: invoice.due_on < Time.zone.today ? "overdue" : "payment_due")
      end

      BillingMailer.payment_rejected(invoice).deliver_later
      invoice
    end

    private
      attr_reader :invoice, :reviewer, :reason

      def proof
        @proof ||= invoice.current_proof
      end
  end
end
