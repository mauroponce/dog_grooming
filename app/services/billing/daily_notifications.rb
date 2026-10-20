module Billing
  class DailyNotifications
    REMINDERS_BY_OFFSET = {
      -4 => "due_4_days",
      -3 => "due_3_days",
      -2 => "due_2_days",
      -1 => "due_1_day",
      0 => "due_today",
      2 => "overdue_2_days"
    }.freeze
    FINAL_GRACE_REMINDER_TYPE = "overdue_3_days"

    def self.call(...)
      new(...).call
    end

    def initialize(today: Time.zone.today, reminder_scheduler: Billing::ReminderScheduler.new)
      @today = today
      @reminder_scheduler = reminder_scheduler
    end

    def call
      Business.where(billing_enabled: true).includes(:owner, :subscription).find_each do |business|
        schedule_business_reminder!(business)
      end

      send_daily_summary!
    end

    private
      attr_reader :today, :reminder_scheduler

      def schedule_business_reminder!(business)
        subscription = business.subscription
        invoice = subscription&.current_invoice
        return if invoice.blank? || subscription.cancelled?
        return if invoice.paid? || invoice.pending_review? || subscription.pending_review?

        if subscription.suspended? && invoice.suspended_at.present?
          if subscription.grace_period_expired?(today: today)
            reminder_scheduler.schedule!(
              invoice,
              "suspended_notice",
              event_on: subscription.effective_grace_ends_on + 1.day
            )
          end
          return
        end

        return if subscription.grace_period_expired?(today: today)

        schedule_due_reminder!(invoice)
        schedule_final_grace_reminder!(invoice)
      end

      def schedule_due_reminder!(invoice)
        reminder_type = REMINDERS_BY_OFFSET[(today - invoice.due_on).to_i]
        return if reminder_type.blank?

        reminder_scheduler.schedule!(invoice, reminder_type, event_on: invoice.due_on)
      end

      def schedule_final_grace_reminder!(invoice)
        grace_ends_on = invoice.subscription.effective_grace_ends_on
        return unless grace_ends_on == today

        reminder_scheduler.schedule!(invoice, FINAL_GRACE_REMINDER_TYPE, event_on: grace_ends_on)
      end

      def send_daily_summary!
        recipients.each do |recipient|
          next if daily_summary_sent_today?(recipient)

          BillingMailer.daily_summary(summary, recipient).deliver_now
        end
      end

      def daily_summary_sent_today?(recipient)
        EmailDeliveryLog.where(
          mailer: "BillingMailer",
          action: "daily_summary",
          recipient: recipient,
          status: "sent",
          created_at: today.all_day
        ).exists?
      end

      def recipients
        configured = ENV["BILLING_SUMMARY_EMAIL"].to_s.split(",").map(&:strip).compact_blank
        configured.presence || User.super_admin.limit(3).pluck(:email_address)
      end

      def summary
        @summary ||= begin
          invoices = SubscriptionInvoice.open_for_review.includes(:subscription).joins(:business).where(businesses: { billing_enabled: true })
          pending = invoices.pending_review.count
          overdue = invoices.where(status: %w[overdue rejected]).count
          {
            pending_review_count: pending,
            overdue_count: overdue,
            grace_ending_today_count: invoices.count { |invoice| invoice.subscription.effective_grace_ends_on == today },
            suspending_today_count: invoices.count { |invoice| invoice.subscription.effective_grace_ends_on == today - 1.day },
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
