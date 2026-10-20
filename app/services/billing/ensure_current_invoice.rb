module Billing
  class EnsureCurrentInvoice
    def self.call(...)
      new(...).call
    end

    def initialize(business:, force: false)
      @business = business
      @force = force
    end

    def call
      return unless business.billing_enabled?
      return current_invoice if current_invoice.present?
      return unless should_create_invoice?

      subscription.subscription_invoices.create!(
        business: business,
        period_start: period_start,
        period_end: period_end,
        billing_period_months: subscription.billing_period_months.to_i.presence || 1,
        amount_cents: current_amount_cents,
        plan_selected: subscription.plan_selected,
        status: invoice_status,
        due_on: due_on,
        reference_code: reference_code
      ).tap do |invoice|
        subscription.update!(
          amount_cents: current_amount_cents,
          next_due_on: invoice.due_on,
          grace_ends_on: invoice.due_on + Business::BILLING_GRACE_DAYS.days
        )
      end
    end

    private
      attr_reader :business, :subscription, :force

      def subscription
        @subscription ||= business.subscription || business.create_subscription!(external_reference: "business-#{business.id}-#{SecureRandom.hex(6)}")
      end

      def current_invoice
        @current_invoice ||= subscription.current_invoice
      end

      def should_create_invoice?
        return true if force && !subscription.paid?
        return true if subscription.trialing? && due_on <= 4.days.from_now.to_date
        return true if subscription.next_due_on.present? && subscription.next_due_on <= 7.days.from_now.to_date
        return true if subscription.normalized_status.in?(%w[payment_due overdue restricted suspended])

        false
      end

      def current_amount_cents
        business.billing_amount.total_amount_cents
      end

      def due_on
        @due_on ||= begin
          if subscription.trialing?
            business.trial_ends_at.to_date
          elsif subscription.next_due_on.present?
            subscription.next_due_on
          elsif subscription.paid_until.present?
            subscription.paid_until
          else
            Time.zone.today
          end
        end
      end

      def period_start
        force && subscription.trialing? ? Time.zone.today : due_on
      end

      def period_end
        period_start.advance(months: subscription.billing_period_months.to_i.presence || 1)
      end

      def invoice_status
        due_on < Time.zone.today ? "overdue" : "open"
      end

      def reference_code
        base = "HT-#{business.id.to_s.rjust(5, '0')}-#{period_start.strftime('%b%Y').upcase}"
        return base unless SubscriptionInvoice.exists?(reference_code: base)

        "#{base}-#{SecureRandom.hex(2).upcase}"
      end
  end
end
