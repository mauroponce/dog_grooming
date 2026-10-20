module Billing
  class DailyProcessor
    def self.call(...)
      new(...).call
    end

    def initialize(today: Time.zone.today)
      @today = today
    end

    def call
      Billing::ReminderScheduler.new.recover_stale!

      Business.where(billing_enabled: true).includes(:subscription).find_each do |business|
        process_business(business)
      end
    end

    private
      attr_reader :today

      def process_business(business)
        subscription = business.subscription || business.create_subscription!(external_reference: "business-#{business.id}-#{SecureRandom.hex(6)}")
        invoice = Billing::EnsureCurrentInvoice.call(business: business)
        invoice ||= subscription.current_invoice
        sync_without_invoice!(business, subscription) and return if invoice.blank?
        return if subscription.cancelled?
        return if subscription.suspended? && invoice.suspended_at.present?

        sync_invoice_status!(invoice)
        return if invoice.paid? || invoice.pending_review? || subscription.pending_review?

        suspend_if_needed!(invoice) if subscription.grace_period_expired?(today: today)
      end

      def sync_without_invoice!(business, subscription)
        return if subscription.paid? || subscription.pending_review? || subscription.suspended? || subscription.cancelled?
        return if business.trial_active?

        subscription.update!(status: business.trial_grace_period_active? ? "payment_due" : "overdue")
      end

      def sync_invoice_status!(invoice)
        return if invoice.paid? || invoice.pending_review?

        subscription = invoice.subscription
        return if subscription.cancelled? || subscription.suspended?

        subscription_status = if subscription.grace_period_expired?(today: today)
          "suspended"
        elsif subscription.restricted?
          "restricted"
        elsif subscription.paid?
          "active"
        elsif invoice.due_on < today
          "overdue"
        elsif invoice.due_today?
          "payment_due"
        elsif subscription.trialing?
          "trialing"
        else
          "payment_due"
        end

        invoice_status = invoice.due_on < today ? "overdue" : "open"
        invoice.update!(status: invoice_status, overdue_at: Time.current) if invoice.status != invoice_status && !invoice.rejected?
        subscription.update!(status: subscription_status)
      end

      def suspend_if_needed!(invoice)
        return unless invoice.subscription.grace_period_expired?(today: today)

        invoice.with_lock do
          subscription = invoice.subscription.reload
          invoice.update!(suspended_at: Time.current) if invoice.suspended_at.blank?
          if !subscription.suspended? || subscription.suspended_at.blank?
            subscription.update!(status: "suspended", suspended_at: Time.current)
          end
        end
      end
  end
end
