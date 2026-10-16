module Admin
  module Appointments
    class ContextMenuPresenter < RowActionsPresenter
      def title
        case menu_state
        when :proof_review then "Revisá el comprobante"
        when :deposit_pending then "Confirmá este turno"
        when :confirmed then "Cerrá el turno y fidelizá"
        when :canceled then "Turno cancelado"
        when :completed then "Turno realizado"
        when :closed then "Turno cerrado"
        else "Revisá este turno"
        end
      end

      def description
        case menu_state
        when :proof_review
          "Si el comprobante coincide con el monto y titular, aprobá la seña. Si no se ve claro, rechazalo con motivo."
        when :deposit_pending
          "La forma más segura es pedir la seña. Si la clienta ya pagó por otro medio, podés confirmar manualmente."
        when :confirmed
          "Guardá nota interna, foto si corresponde y dejá preparado el seguimiento del cliente."
        when :canceled
          "Este turno ya no requiere acciones operativas."
        when :completed
          "Podés consultar el historial o sugerir el próximo turno."
        when :closed
          "Este turno ya no requiere acciones urgentes. Podés consultar el detalle o el historial."
        else
          "Revisá el estado del turno y contactá a la clienta si necesitás confirmar datos."
        end
      end

      def context_badges
        [
          Badge.new(label: badge_prefix, tone: tone),
          primary_status_badge
        ].compact
      end

      def primary_actions
        @primary_actions ||= unique_actions(primary_actions_for_state).first(3)
      end

      def secondary_actions
        @secondary_actions ||= begin
          limit = destructive_actions.any? ? 3 : 4
          excluded_keys = primary_actions.map(&:key) + destructive_actions.map(&:key)
          unique_actions(secondary_actions_for_state).reject { |action| excluded_keys.include?(action.key) }.first(limit)
        end
      end

      def destructive_actions
        @destructive_actions ||= begin
          can_cancel_context? ? [ cancel_action ] : []
        end
      end

      def tone
        case menu_state
        when :proof_review then :amber
        when :deposit_pending then :rose
        when :confirmed, :completed then :emerald
        when :canceled, :closed then :zinc
        else :amber
        end
      end

      def recommended_action_key
        primary_actions.first&.key
      end

      def expandable?
        primary_actions.any? || secondary_actions.any? || destructive_actions.any? || show_finalization_form?
      end

      def show_finalization_form?
        primary_actions.any? { |action| action.key == "finalize" }
      end

      private
        def menu_state
          @menu_state ||= begin
            return :canceled if booking.canceled?
            return :completed if booking.completed?
            return :closed if booking.terminal_status?
            return :proof_review if booking.pending_deposit_review? || deposit_submitted_for_review?
            return :deposit_pending if deposit_pending?
            return :confirmed if booking.confirmed?

            :pending
          end
        end

        def badge_prefix
          return "Historial" if menu_state.in?(%i[canceled completed closed])

          "Acción recomendada"
        end

        def primary_actions_for_state
          case menu_state
          when :proof_review
            [
              view_receipt_action,
              approve_deposit_action_if_allowed,
              reject_deposit_action_if_allowed
            ]
          when :deposit_pending
            [
              send_deposit_link_action,
              confirm_manual_action_if_allowed
            ]
          when :confirmed
            confirmed_primary_actions
          when :canceled
            [
              detail_action,
              reschedule_action_if_allowed
            ]
          when :completed
            [
              history_action,
              suggested_next_booking_action
            ]
          when :closed
            [
              history_action,
              reschedule_action_if_allowed
            ]
          else
            [
              confirm_manual_action_if_allowed,
              detail_action
            ]
          end
        end

        def confirmed_primary_actions
          actions = []
          if booking.finalizable? && can_finalize?
            actions << finalize_action(label: "Finalizar con nota")
          elsif booking.starts_at.future?
            actions << detail_action
          end
          actions << suggested_next_booking_action
          actions
        end

        def secondary_actions_for_state
          case menu_state
          when :proof_review
            [
              detail_action,
              copy_booking_link_action
            ]
          when :deposit_pending
            [
              detail_action,
              reschedule_action_if_allowed,
              copy_booking_link_action
            ]
          when :confirmed
            [
              customer_history_action,
              detail_action,
              copy_booking_link_action
            ]
          when :canceled
            [
              detail_action,
              copy_booking_link_action
            ]
          when :completed, :closed
            [
              detail_action,
              copy_booking_link_action
            ]
          else
            [
              detail_action,
              reschedule_action_if_allowed,
              copy_booking_link_action
            ]
          end
        end

        def view_receipt_action
          action = receipt_action || review_proof_action
          with_action(action, label: action&.key == "receipt" ? "Ver archivo" : "Abrir comprobante", tone: :neutral)
        end

        def approve_deposit_action_if_allowed
          approve_deposit_action if booking.pending_deposit_review? && can_approve_deposit?
        end

        def reject_deposit_action_if_allowed
          reject_deposit_action if booking.manual_payment_required? && !booking.confirmed? && can_reject_deposit?
        end

        def send_deposit_link_action
          with_action(send_deposit_action, key: "send_deposit_link", label: "Enviar link de seña", tone: :ink)
        end

        def confirm_manual_action_if_allowed
          confirm_manual_action if !booking.confirmed? && !booking.terminal_status? && can_confirm?
        end

        def reschedule_action_if_allowed
          reschedule_action if can_reschedule?
        end

        def can_reschedule?
          booking.customer_profile.present? && can_create_bookings? && appointment_policy.update?
        end

        def can_cancel_context?
          cancellable_now? && can_cancel?
        end

        def with_action(action, key: nil, label: nil, tone: nil)
          return if action.blank?

          action.key = key if key.present?
          action.label = label if label.present?
          action.tone = tone if tone.present?
          action
        end

        def unique_actions(actions)
          actions.compact_blank.uniq(&:key)
        end
    end
  end
end
