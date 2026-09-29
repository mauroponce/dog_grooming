module Billing
  class DailyProcessor
    REMINDERS_BY_OFFSET = {
      -7 => "due_7_days",
      -3 => "due_3_days",
      0 => "due_today",
      2 => "overdue_2_days",
      5 => "overdue_5_days",
      10 => "overdue_10_days"
    }.freeze

    def self.call(...)
      new(...).call
    end

    def initialize(today: Time.zone.today)
      @today = today
    end

    def call
      Business.where(billing_enabled: true).includes(:owner, :subscription).find_each do |business|
        process_business(business)
      end

      send_daily_summary!
    end

    private
      attr_reader :today

      def process_business(business)
        return unless business.billing_enabled?

        subscription = business.subscription || business.create_subscription!(external_reference: "business-#{business.id}-#{SecureRandom.hex(6)}")
        if subscription.mercado_pago?
          begin
            PlatformMercadoPago::SyncSubscription.call(subscription) if subscription.provider_subscription_id.present?
          rescue PlatformMercadoPago::Client::Error => error
            Rails.logger.warn("No se pudo sincronizar la suscripción #{subscription.id}: #{error.message}")
          end
          return
        end
        invoice = Billing::EnsureCurrentInvoice.call(business: business)
        invoice ||= subscription.current_invoice
        sync_without_invoice!(business, subscription) and return if invoice.blank?

        sync_invoice_status!(invoice)
        return if invoice.pending_review? || subscription.pending_review?

        send_due_reminder_if_needed!(invoice)
        restrict_if_needed!(invoice)
        suspend_if_needed!(invoice)
      end

      def sync_without_invoice!(business, subscription)
        return if subscription.paid? || subscription.pending_review? || subscription.suspended? || subscription.cancelled?
        return if business.trial_active?

        subscription.update!(status: business.trial_grace_period_active? ? "payment_due" : "overdue")
      end

      def sync_invoice_status!(invoice)
        return if invoice.paid? || invoice.pending_review?

        days = invoice.days_overdue
        subscription_status = if days >= 15
          "suspended"
        elsif days >= 10
          "restricted"
        elsif days.positive?
          "overdue"
        elsif invoice.due_today?
          "payment_due"
        elsif invoice.subscription.trialing? && invoice.due_on > today
          "trialing"
        else
          "payment_due"
        end

        invoice_status = days.positive? ? "overdue" : "open"
        invoice.update!(status: invoice_status, overdue_at: Time.current) if invoice.status != invoice_status && !invoice.rejected?
        invoice.subscription.update!(status: subscription_status)
      end

      def send_due_reminder_if_needed!(invoice)
        offset = invoice.due_on < today ? invoice.days_overdue : (invoice.due_on - today).to_i * -1
        reminder_type = REMINDERS_BY_OFFSET[offset]
        return if reminder_type.blank?

        send_reminder!(invoice, reminder_type)
      end

      def restrict_if_needed!(invoice)
        return unless invoice.days_overdue >= 10
        return if invoice.subscription.restricted? || invoice.subscription.suspended?

        invoice.update!(restricted_at: Time.current)
        invoice.subscription.update!(status: "restricted", restricted_at: Time.current)
        send_reminder!(invoice, "restricted_notice")
      end

      def suspend_if_needed!(invoice)
        return unless invoice.days_overdue >= 15
        return if invoice.subscription.suspended?

        invoice.update!(suspended_at: Time.current)
        invoice.subscription.update!(status: "suspended", suspended_at: Time.current)
        BillingMailer.account_suspended(invoice).deliver_later unless reminder_sent?(invoice, "suspended_notice", "email")
        create_reminder_record!(invoice, "suspended_notice", "email", invoice.business.owner.email_address)
      end

      def send_reminder!(invoice, reminder_type)
        send_email_reminder!(invoice, reminder_type)
      end

      def send_email_reminder!(invoice, reminder_type)
        return if reminder_sent?(invoice, reminder_type, "email")

        BillingMailer.reminder(invoice, reminder_type).deliver_later
        create_reminder_record!(invoice, reminder_type, "email", invoice.business.owner.email_address)
      end

      def reminder_sent?(invoice, reminder_type, channel)
        BillingReminder.where(subscription_invoice: invoice, reminder_type: reminder_type, channel: channel, status: "sent").exists?
      end

      def create_reminder_record!(invoice, reminder_type, channel, recipient)
        BillingReminder.create!(
          business: invoice.business,
          subscription_invoice: invoice,
          reminder_type: reminder_type,
          sent_at: Time.current,
          channel: channel,
          recipient: recipient,
          status: "sent"
        )
      rescue ActiveRecord::RecordInvalid
        nil
      end

      def send_daily_summary!
        recipients.each do |recipient|
          BillingMailer.daily_summary(summary, recipient).deliver_later
        end
      end

      def recipients
        configured = ENV["BILLING_SUMMARY_EMAIL"].to_s.split(",").map(&:strip).compact_blank
        configured.presence || User.super_admin.limit(3).pluck(:email_address)
      end

      def summary
        @summary ||= begin
          invoices = SubscriptionInvoice.open_for_review.joins(:business).where(businesses: { billing_enabled: true })
          pending = invoices.pending_review.count
          overdue = invoices.where(status: %w[overdue rejected]).count
          {
            pending_review_count: pending,
            overdue_count: overdue,
            restricting_today_count: invoices.select { |invoice| invoice.days_overdue == 10 }.size,
            suspending_today_count: invoices.select { |invoice| invoice.days_overdue == 15 }.size,
            trials_ending_count: Business.where(billing_enabled: true, trial_ends_at: today.beginning_of_day..7.days.from_now.end_of_day).count,
            mrr_label: money_label(Business.includes(:subscription).select(&:subscription_active?).sum(&:monthly_amount_cents)),
            overdue_label: money_label(invoices.where(status: %w[overdue rejected]).sum(:amount_cents))
          }
        end
      end

      def money_label(cents)
        "$#{(cents.to_i / 100).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
      end
  end
end
