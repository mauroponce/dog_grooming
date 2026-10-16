module Admin
  module Appointments
    class PrimaryActionPresenter < RowActionsPresenter
      def primary_action
        @primary_action ||= begin
          if booking.pending_deposit_review? && can_review_deposit?
            review_proof_action
          elsif deposit_pending?
            send_deposit_action
          elsif booking.confirmed? && booking.starts_at.future?
            view_turn_action
          elsif booking.confirmed? && booking.starts_at <= Time.current && can_finalize?
            finalize_detail_action
          elsif pending_without_required_deposit? && can_confirm?
            confirm_action
          elsif booking.canceled?
            view_turn_action
          elsif booking.completed?
            history_detail_action
          else
            view_turn_action
          end
        end
      end

      def show_secondary_detail_button?
        primary_action.blank? || primary_action.key != "view_turn"
      end

      private
        def view_turn_action
          Action.new(
            key: "view_turn",
            label: "Ver turno",
            url: routes.admin_appointment_path(booking),
            method: :get,
            tone: :neutral
          )
        end

        def history_detail_action
          Action.new(
            key: "view_history",
            label: "Ver historial",
            url: routes.admin_appointment_path(booking, anchor: "historial"),
            method: :get,
            tone: :neutral
          )
        end

        def finalize_detail_action
          Action.new(
            key: "finalize",
            label: "Finalizar",
            url: routes.admin_appointment_path(booking, anchor: "appointment_#{booking.short_uuid}_finalization"),
            method: :get,
            tone: :ink
          )
        end
    end
  end
end
