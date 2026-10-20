module Billing
  class DailyProcessor
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

    def initialize(today: Time.zone.today)
      @today = today
    end

    def call
      recover_stale_reminders!

      Business.where(billing_enabled: true).includes(:owner, :subscription).find_each do |business|
        process_business(business)
      end

      send_daily_summary!
    end

    private
      attr_reader :today

      def recover_stale_reminders!
        stale_before = BillingReminder::ENQUEUE_LEASE.ago
        pending = BillingReminder.where(status: "pending").where(
          "(enqueued_at IS NULL AND created_at <= :stale_before) OR enqueued_at <= :stale_before",
          stale_before: stale_before
        )
        failed = BillingReminder.where(status: "failed", updated_at: ..stale_before)

        pending.or(failed).find_each { |reminder| enqueue_reminder!(reminder) }
      end

      def process_business(business)
        return unless business.billing_enabled?

        subscription = business.subscription || business.create_subscription!(external_reference: "business-#{business.id}-#{SecureRandom.hex(6)}")
        invoice = Billing::EnsureCurrentInvoice.call(business: business)
        invoice ||= subscription.current_invoice
        sync_without_invoice!(business, subscription) and return if invoice.blank?
        return if subscription.cancelled?
        if subscription.suspended? && invoice.suspended_at.present?
          schedule_suspension_notice!(invoice) if subscription.grace_period_expired?(today: today)
          return
        end

        sync_invoice_status!(invoice)
        return if invoice.paid? || invoice.pending_review? || subscription.pending_review?

        if subscription.grace_period_expired?(today: today)
          suspend_if_needed!(invoice)
        else
          send_due_reminder_if_needed!(invoice)
          send_final_grace_reminder_if_needed!(invoice)
        end
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

      def send_due_reminder_if_needed!(invoice)
        offset = (today - invoice.due_on).to_i
        reminder_type = REMINDERS_BY_OFFSET[offset]
        return if reminder_type.blank?

        schedule_reminder!(invoice, reminder_type, event_on: invoice.due_on)
      end

      def send_final_grace_reminder_if_needed!(invoice)
        grace_ends_on = invoice.subscription.effective_grace_ends_on
        return unless grace_ends_on == today

        schedule_reminder!(invoice, FINAL_GRACE_REMINDER_TYPE, event_on: grace_ends_on)
      end

      def suspend_if_needed!(invoice)
        return unless invoice.subscription.grace_period_expired?(today: today)

        reminder = nil
        invoice.with_lock do
          invoice.update!(suspended_at: Time.current) if invoice.suspended_at.blank?
          if !invoice.subscription.suspended? || invoice.subscription.suspended_at.blank?
            invoice.subscription.update!(status: "suspended", suspended_at: Time.current)
          end
          reminder = find_or_create_reminder!(
            invoice,
            "suspended_notice",
            event_on: invoice.subscription.effective_grace_ends_on + 1.day
          )
        end
        enqueue_reminder!(reminder)
      end

      def schedule_suspension_notice!(invoice)
        schedule_reminder!(
          invoice,
          "suspended_notice",
          event_on: invoice.subscription.effective_grace_ends_on + 1.day
        )
      end

      def schedule_reminder!(invoice, reminder_type, event_on:)
        reminder = find_or_create_reminder!(invoice, reminder_type, event_on: event_on)
        enqueue_reminder!(reminder)
      end

      def find_or_create_reminder!(invoice, reminder_type, event_on:)
        attributes = {
          subscription_invoice: invoice,
          reminder_type: reminder_type,
          channel: "email",
          recipient: invoice.business.owner.email_address,
          event_on: event_on
        }
        BillingReminder.find_by(attributes) || BillingReminder.create!(
          attributes.merge(business: invoice.business, status: "pending")
        )
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        BillingReminder.find_by!(attributes)
      end

      def enqueue_reminder!(reminder)
        job = nil
        reminder.with_lock do
          return unless reminder.recoverable?
          return if reminder.enqueued_at.present? && reminder.enqueued_at > BillingReminder::ENQUEUE_LEASE.ago
          return if active_job_present?(reminder.active_job_id)

          job = Billing::SendReminderJob.new(reminder.id)
          reminder.update!(status: "pending", enqueued_at: Time.current, active_job_id: job.job_id)
        end

        job.enqueue
        raise ActiveJob::EnqueueError, "No se pudo encolar el recordatorio de facturación." unless job.successfully_enqueued?

        true
      rescue StandardError => error
        reminder&.with_lock do
          if reminder.recoverable? && (job.blank? || reminder.active_job_id == job.job_id)
            reminder.update!(status: "failed", enqueued_at: nil, active_job_id: nil)
          end
        end
        Rails.logger.error("Billing reminder enqueue failed reminder_id=#{reminder&.id}: #{error.class}: #{error.message}")
        false
      end

      def active_job_present?(active_job_id)
        return false if active_job_id.blank?

        SolidQueue::Job
          .where(active_job_id: active_job_id, finished_at: nil)
          .where.missing(:failed_execution)
          .exists?
      rescue StandardError => error
        Rails.logger.warn(
          "Billing reminder queue lookup failed active_job_id=#{active_job_id}: #{error.class}: #{error.message}"
        )
        true
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
