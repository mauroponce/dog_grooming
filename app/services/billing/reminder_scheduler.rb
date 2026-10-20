module Billing
  class ReminderScheduler
    def schedule!(invoice, reminder_type, event_on:)
      reminder = find_or_create!(invoice, reminder_type, event_on: event_on)
      enqueue!(reminder)
      reminder
    end

    def recover_stale!
      stale_before = BillingReminder::ENQUEUE_LEASE.ago
      pending = BillingReminder.where(status: "pending").where(
        "(enqueued_at IS NULL AND created_at <= :stale_before) OR enqueued_at <= :stale_before",
        stale_before: stale_before
      )
      failed = BillingReminder.where(status: "failed", updated_at: ..stale_before)

      pending.or(failed).find_each { |reminder| enqueue!(reminder) }
    end

    private
      def find_or_create!(invoice, reminder_type, event_on:)
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

      def enqueue!(reminder)
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
  end
end
