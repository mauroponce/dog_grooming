module Admin
  class NotificationItem
    TYPE_ALIASES = {
      "deposit_receipt_submitted" => "new_deposit_proof",
      "deposit_receipt_uploaded_manually" => "new_deposit_proof",
      "customer_uploaded_proof" => "new_deposit_proof",
      "customer_replaced_proof" => "new_deposit_proof",
      "mercado_pago_payment_approved" => "new_booking",
      "waitlist_entry_created" => "waitlist_entry",
      "waitlist_released_slot" => "waitlist_entry",
      "follow_up_suggested" => "follow_up_due",
      "customer_reminder_due" => "follow_up_due",
      "customer_cancelled_booking" => "booking_cancelled",
      "appointment_cancelled_from_finalization" => "booking_cancelled",
      "appointment_rescheduled" => "booking_cancelled",
      "deposit_deadline_expired" => "system_notice",
      "ai_chat_followup" => "system_notice",
      "customer_late_cancellation_alert" => "system_notice"
    }.freeze

    attr_reader :event

    def initialize(event)
      @event = event
    end

    delegate :title, :body, :created_at, :read_at, :metadata, to: :event

    def notification_type
      TYPE_ALIASES.fetch(event.event_type, event.event_type)
    end

    def unread?
      read_at.blank?
    end

    def read?
      !unread?
    end

    def urgent?
      notification_type.in?(%w[deposit_rejected subscription_overdue system_notice])
    end

    def tone
      case notification_type
      when "new_deposit_proof", "trial_ending", "subscription_overdue", "system_notice"
        :amber
      when "new_booking", "follow_up_due", "fillable_gap"
        :zinc
      when "deposit_approved"
        :emerald
      when "deposit_rejected", "booking_cancelled"
        :rose
      when "customer_requested_reschedule"
        :amber
      when "waitlist_entry"
        :sky
      else
        :zinc
      end
    end

    def action_label
      metadata["action_label"].presence || default_action_label
    end

    def action_url
      default_action_url.presence || metadata["action_url"].presence || metadata["whatsapp_url"].presence
    end

    def external_action?
      action_url.to_s.match?(/\Ahttps?:\/\//)
    end

    private
      def route_helpers
        Rails.application.routes.url_helpers
      end

      def appointment_id
        metadata["appointment_id"].presence
      end

      def appointment
        @appointment ||= event.business.appointments.find_by(id: appointment_id)
      end

      def appointment_detail_path
        route_helpers.admin_appointment_path(appointment) if appointment
      end

      def default_action_label
        case notification_type
        when "new_deposit_proof"
          "Abrir comprobante"
        when "trial_ending", "subscription_overdue"
          "Ver suscripción"
        when "new_booking", "booking_cancelled", "customer_requested_reschedule"
          "Ver turno"
        when "waitlist_entry"
          "Ver lista"
        when "follow_up_due"
          "Abrir WhatsApp"
        when "fillable_gap"
          "Ofrecer turno"
        else
          metadata["action_url"].present? ? "Abrir" : nil
        end
      end

      def default_action_url
        case notification_type
        when "new_deposit_proof"
          appointment_action_url
        when "trial_ending", "subscription_overdue"
          route_helpers.admin_calendar_path
        when "booking_cancelled"
          return metadata["action_url"].presence if event.event_type == "customer_cancelled_booking"

          appointment_detail_path || route_helpers.admin_calendar_path
        when "new_booking", "customer_requested_reschedule"
          appointment_detail_path || route_helpers.admin_calendar_path
        when "waitlist_entry"
          metadata["action_url"].presence || route_helpers.admin_calendar_path(waitlist: "1")
        when "follow_up_due"
          metadata["whatsapp_url"].presence || metadata["action_url"].presence
        when "fillable_gap"
          route_helpers.admin_calendar_path
        end
      end

      def appointment_action_url
        stored_url = metadata["action_url"].presence
        return stored_url unless stored_url&.include?("appointment_id")

        appointment_detail_path || stored_url
      end
  end
end
