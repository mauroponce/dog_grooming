module Billing
  class SendReminderJob < ApplicationJob
    self.enqueue_after_transaction_commit = true
    queue_as :default

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(reminder_id)
      reminder = BillingReminder.find_by(id: reminder_id)
      return if reminder.blank?

      delivery_error = nil
      reminder.with_lock do
        return if reminder.sent?
        unless deliverable?(reminder)
          reminder.update!(status: "skipped", sent_at: nil)
          return
        end

        begin
          delivery_for(reminder).deliver_now
          reminder.update!(status: "sent", sent_at: Time.current)
        rescue StandardError => error
          reminder.update!(status: "failed", sent_at: nil)
          delivery_error = error
        end
      end

      raise delivery_error if delivery_error
    end

    private
      def delivery_for(reminder)
        invoice = reminder.subscription_invoice
        if reminder.reminder_type == "suspended_notice"
          BillingMailer.account_suspended(invoice)
        else
          BillingMailer.reminder(invoice, reminder.reminder_type)
        end
      end

      def deliverable?(reminder)
        invoice = reminder.subscription_invoice
        subscription = invoice.subscription
        return false if invoice.paid? || invoice.pending_review? || subscription.pending_review? || subscription.cancelled?

        if reminder.reminder_type == "suspended_notice"
          return subscription.suspended? &&
            subscription.grace_period_expired? &&
            reminder.event_on == subscription.effective_grace_ends_on + 1.day &&
            Time.zone.today >= reminder.event_on
        end

        if reminder.reminder_type == Billing::DailyProcessor::FINAL_GRACE_REMINDER_TYPE
          return reminder.event_on == subscription.effective_grace_ends_on && Time.zone.today == reminder.event_on
        end

        offset = (Time.zone.today - invoice.due_on).to_i
        reminder.event_on == invoice.due_on && Billing::DailyProcessor::REMINDERS_BY_OFFSET[offset] == reminder.reminder_type
      end
  end
end
