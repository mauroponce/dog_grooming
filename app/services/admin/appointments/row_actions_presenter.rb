module Admin
  module Appointments
    class RowActionsPresenter
      Action = Struct.new(
        :key,
        :label,
        :url,
        :method,
        :tone,
        :target,
        :params,
        :copy_text,
        :anchor,
        keyword_init: true
      ) do
        def external?
          target == "_blank"
        end

        def copy?
          copy_text.present?
        end

        def form?
          method.present? && method.to_s != "get"
        end

        def anchor?
          anchor.present?
        end
      end

      Group = Struct.new(:title, :actions, keyword_init: true)
      Badge = Struct.new(:label, :tone, keyword_init: true)

      attr_reader :booking, :current_user, :current_business

      def initialize(booking:, current_user:, current_business:)
        @booking = booking
        @current_user = current_user
        @current_business = current_business
      end

      def primary_action
        return review_proof_action if booking.pending_deposit_review? && can_review_deposit?
        return send_deposit_action if deposit_pending?
        return finalize_action if booking.confirmed? && booking.starts_at < Time.current && can_finalize?
        return detail_action if booking.confirmed? && booking.starts_at >= Time.current
        return confirm_action if pending_without_required_deposit? && can_confirm?
        return history_action if booking.completed?

        detail_action
      end

      def action_groups
        [
          confirmation_group,
          post_booking_group,
          links_group,
          follow_up_group,
          management_group
        ].compact_blank
      end

      def expandable?
        action_groups.any? { |group| group.actions.any? }
      end

      def row_tone
        return :amber if booking.pending_deposit_review?
        return :rose if deposit_pending?

        :neutral
      end

      def status_badges
        [ primary_status_badge ]
      end

      def deposit_summary
        return unless booking.deposit_required?

        "Seña: #{booking.formatted_deposit_amount} · Saldo: #{booking.formatted_remaining_balance}"
      end

      def meta_line
        [ booking.employee_membership&.name, booking.branch&.name, booking.bookable_resource&.name ].compact_blank.join(" · ")
      end

      private
        def confirmation_group
          actions = []
          actions << approve_deposit_action if booking.pending_deposit_review? && can_approve_deposit?
          actions << reject_deposit_action if booking.manual_payment_required? && !booking.confirmed? && can_reject_deposit?
          actions << confirm_manual_action if !booking.confirmed? && !booking.terminal_status? && can_confirm?
          actions << deposit_link_action if booking.manual_payment_required? && !booking.confirmed?
          build_group("Confirmación", actions)
        end

        def post_booking_group
          actions = []
          if booking.finalizable? && can_finalize?
            actions << finalize_action(label: "Finalizar con nota")
            actions << finalize_action(label: "Subir foto")
          end
          build_group("Post-turno", actions)
        end

        def links_group
          actions = [
            copy_booking_link_action,
            mobile_review_action,
            receipt_action
          ].compact
          build_group("Links", actions)
        end

        def follow_up_group
          actions = []
          actions << suggested_next_booking_action if booking.customer_profile.present? && can_create_bookings?
          actions << customer_history_action if booking.customer_profile.present? && can_view_customers?
          build_group("Seguimiento", actions)
        end

        def management_group
          actions = [ detail_action ]
          actions << reschedule_action if booking.customer_profile.present? && can_create_bookings? && !booking.terminal_status?
          actions << mark_no_show_action if booking.finalizable? && can_finalize?
          actions << cancel_action if cancellable_now? && can_cancel?
          build_group("Gestión", actions)
        end

        def build_group(title, actions)
          actions = actions.compact_blank
          return if actions.blank?

          Group.new(title: title, actions: actions)
        end

        def review_proof_action
          Action.new(key: "review_proof", label: "Revisar", url: routes.admin_appointment_path(booking), method: :get, tone: :amber)
        end

        def approve_deposit_action
          Action.new(key: "approve_deposit", label: "Aprobar seña", url: routes.approve_deposit_admin_appointment_path(booking), method: :patch, tone: :emerald)
        end

        def reject_deposit_action
          Action.new(
            key: "reject_deposit",
            label: "Rechazar seña",
            url: routes.reject_deposit_admin_appointment_path(booking),
            method: :patch,
            tone: :rose,
            params: { reason: "Rechazado desde panel" }
          )
        end

        def send_deposit_action
          Action.new(key: "send_deposit", label: "Ver link de seña", url: booking.deposit_upload_url, method: :get, tone: :ink, target: "_blank")
        end

        def deposit_link_action
          Action.new(key: "deposit_link", label: "Enlace de seña", url: booking.deposit_upload_url, method: :get, tone: :neutral, target: "_blank")
        end

        def confirm_action
          Action.new(key: "confirm", label: "Confirmar", url: routes.confirm_admin_appointment_path(booking), method: :patch, tone: :emerald)
        end

        def confirm_manual_action
          Action.new(key: "confirm_manual", label: "Confirmar manual", url: routes.confirm_admin_appointment_path(booking), method: :patch, tone: :emerald)
        end

        def finalize_action(label: "Finalizar")
          Action.new(key: "finalize", label: label, tone: :ink, anchor: "appointment_#{booking.short_uuid}_finalization")
        end

        def copy_booking_link_action
          Action.new(key: "copy_link", label: "Copiar link", tone: :neutral, copy_text: booking.customer_portal_booking_url)
        end

        def mobile_review_action
          return unless booking.manual_payment_required?

          Action.new(key: "mobile_review", label: "Revisión móvil", url: booking.deposit_review_url, method: :get, tone: :neutral, target: "_blank")
        end

        def receipt_action
          return unless booking.deposit_receipt.attached?

          Action.new(key: "receipt", label: "Comprobante", url: routes.download_receipt_admin_appointment_path(booking), method: :get, tone: :neutral)
        end

        def detail_action
          Action.new(key: "detail", label: booking.terminal_status? ? "Ver historial" : "Ver detalle", url: routes.admin_appointment_path(booking), method: :get, tone: :neutral)
        end

        def history_action
          detail_action.tap { |action| action.label = "Ver historial" }
        end

        def suggested_next_booking_action
          Action.new(key: "suggest_next", label: "Sugerir próximo", url: routes.new_admin_appointment_path(customer_profile_id: booking.customer_profile_id), method: :get, tone: :emerald)
        end

        def customer_history_action
          Action.new(key: "history", label: "Ver historial", url: routes.edit_admin_customer_profile_path(booking.customer_profile, section: "appointments"), method: :get, tone: :neutral)
        end

        def reschedule_action
          Action.new(key: "reschedule", label: "Reprogramar", url: routes.new_admin_appointment_path(customer_profile_id: booking.customer_profile_id), method: :get, tone: :neutral)
        end

        def mark_no_show_action
          Action.new(
            key: "mark_no_show",
            label: "Marcar no asistió",
            url: routes.finalize_admin_appointment_path(booking),
            method: :patch,
            tone: :rose,
            params: { finalization: { outcome: "no_show" } }
          )
        end

        def cancel_action
          Action.new(key: "cancel", label: "Cancelar", url: routes.cancel_admin_appointment_path(booking), method: :patch, tone: :rose)
        end

        def deposit_pending?
          booking.deposit_required? && booking.deposit_status.in?(%w[pending rejected failed]) && !booking.confirmed?
        end

        def pending_without_required_deposit?
          !booking.deposit_required? && !booking.terminal_status? && !booking.confirmed?
        end

        def status_tone
          return :amber if deposit_submitted_for_review?
          return :rose if deposit_rejected?

          Appointment.status_tone(booking.status)
        end

        def primary_status_badge
          return Badge.new(label: Appointment.status_label("pending_deposit_review"), tone: :amber) if booking.pending_deposit_review? || deposit_submitted_for_review?
          return Badge.new(label: Appointment.status_label("pending_deposit"), tone: :rose) if booking.deposit_rejected? || deposit_rejected?
          return Badge.new(label: "Pago pendiente", tone: :rose) if deposit_pending?
          return Badge.new(label: "Por finalizar", tone: :violet) if needs_completion?

          Badge.new(label: booking.status_label, tone: status_tone)
        end

        def deposit_submitted_for_review?
          booking.deposit_required? && booking.deposit_status == "submitted" && !booking.confirmed?
        end

        def deposit_rejected?
          booking.deposit_required? && booking.deposit_status.in?(%w[rejected failed]) && !booking.confirmed?
        end

        def needs_completion?
          booking.confirmed? && booking.starts_at < Time.current
        end

        def appointment_policy
          @appointment_policy ||= AppointmentPolicy.new(current_user, booking)
        end

        def business_policy
          @business_policy ||= BusinessPolicy.new(current_user, current_business)
        end

        def can_review_deposit?
          appointment_policy.review_deposit?
        end

        def can_approve_deposit?
          appointment_policy.approve_deposit?
        end

        def can_reject_deposit?
          appointment_policy.reject_deposit?
        end

        def can_confirm?
          appointment_policy.confirm?
        end

        def can_cancel?
          appointment_policy.cancel?
        end

        def cancellable_now?
          !booking.terminal_status? && booking.starts_at.future?
        end

        def can_finalize?
          appointment_policy.finalize?
        end

        def can_create_bookings?
          AppointmentPolicy.new(current_user, current_business.appointments.new).create?
        end

        def can_view_customers?
          business_policy.customers?
        end

        def routes
          Rails.application.routes.url_helpers
        end
    end
  end
end
