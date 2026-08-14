module Admin
  module AppointmentsHelper
    def appointment_filter_options
      [
        [ "Todos", nil ],
        [ "Hoy", "today" ],
        [ "Confirmado", "confirmed" ],
        [ "Seña pendiente", "pending_deposit" ],
        [ "Comprobante", "pending_deposit_review" ],
        [ "Realizado", "completed" ],
        [ "No asistió", "no_show" ],
        [ "Cancelado", "canceled" ],
        [ "Vencido", "expired" ],
        [ "Por finalizar", "needs_completion" ]
      ]
    end

    def appointment_filter_classes(active)
      if active
        "inline-flex h-11 items-center justify-center rounded-2xl bg-ink px-4 text-sm font-bold text-white"
      else
        "inline-flex h-11 items-center justify-center rounded-2xl border border-zinc-200 bg-white px-4 text-sm font-bold text-zinc-700 transition hover:bg-zinc-50"
      end
    end

    def appointment_badge_classes(tone)
      {
        amber: "bg-amber-50 text-amber-700",
        brand: "bg-brand-50 text-brand-700",
        emerald: "bg-emerald-50 text-emerald-700",
        rose: "bg-rose-50 text-rose-700",
        violet: "bg-brand-50 text-brand-700",
        zinc: "bg-zinc-100 text-zinc-600"
      }.fetch(tone, "bg-zinc-100 text-zinc-600")
    end

    def appointment_panel_classes(appointment)
      return "border-amber-200 bg-white" if appointment.pending_deposit_review?
      return "border-rose-200 bg-white" if appointment.deposit_required? && appointment.deposit_status.in?(%w[pending rejected failed]) && !appointment.confirmed?

      "border-white bg-white"
    end

    def appointment_action_classes(tone)
      {
        amber: "rounded-2xl bg-amber-600 px-4 py-2.5 text-sm font-bold text-white whitespace-nowrap transition hover:bg-amber-700",
        emerald: "rounded-2xl bg-emerald-600 px-4 py-2.5 text-sm font-bold text-white whitespace-nowrap transition hover:bg-emerald-700",
        ink: "rounded-2xl bg-ink px-4 py-2.5 text-sm font-bold text-white whitespace-nowrap transition hover:bg-zinc-800",
        rose: "rounded-2xl border border-rose-200 bg-rose-50 px-4 py-2.5 text-sm font-bold text-rose-700 whitespace-nowrap transition hover:bg-rose-100",
        brand: "rounded-2xl border border-brand-200 bg-brand-50 px-4 py-2.5 text-sm font-bold text-brand-700 whitespace-nowrap transition hover:bg-brand-100",
        neutral: "rounded-2xl border border-zinc-200 bg-white px-4 py-2.5 text-sm font-bold text-zinc-700 whitespace-nowrap transition hover:bg-zinc-50"
      }.fetch(tone, "rounded-2xl border border-zinc-200 bg-white px-4 py-2.5 text-sm font-bold text-zinc-700 whitespace-nowrap transition hover:bg-zinc-50")
    end

    def appointment_meta_line(appointment)
      [ appointment.employee_membership&.name, appointment.branch&.name, appointment.bookable_resource&.name ].compact_blank.join(" · ")
    end

    def appointment_status_hint(appointment)
      return "Comprobante para revisar." if appointment.pending_deposit_review? || appointment_deposit_submitted_for_review?(appointment)
      return "Todavía no envió comprobante." if appointment_deposit_pending?(appointment)
      return "Listo para finalizar." if appointment.confirmed? && appointment.starts_at <= Time.current
      return "Turno confirmado." if appointment.confirmed?
      return "Guardado en historial." if appointment.completed?
      return "Turno cancelado." if appointment.canceled?
      return "No asistió." if appointment.no_show?
      return "Reprogramado." if appointment.rescheduled?

      "Revisar turno."
    end

    def appointment_status_hint_classes(appointment)
      return "text-amber-700" if appointment.pending_deposit_review? || appointment_deposit_submitted_for_review?(appointment)
      return "text-rose-700" if appointment_deposit_pending?(appointment) || appointment.deposit_rejected?
      return "text-brand-700" if appointment.confirmed? && appointment.starts_at <= Time.current
      return "text-emerald-700" if appointment.confirmed? || appointment.completed?

      "text-zinc-500"
    end

    def appointment_money_rows(appointment)
      if appointment.deposit_required?
        [
          [ "Seña", appointment.formatted_deposit_amount ],
          [ "Saldo", appointment.formatted_remaining_balance ]
        ]
      else
        [
          [ "Seña", "Sin seña" ],
          [ "Total", appointment_detail_money(appointment.final_price_cents) ]
        ]
      end
    end

    def appointment_detail_initials(name)
      parts = name.to_s.split
      initials = parts.first(2).map { |part| part[0] }.join
      initials.presence&.upcase || "HT"
    end

    def appointment_detail_money(cents)
      amount = cents.to_i / 100.0
      precision = (cents.to_i % 100).zero? ? 0 : 2
      number_to_currency(amount, unit: "$", precision:, delimiter: ".", separator: ",")
    end

    def appointment_detail_action_panel_classes(tone)
      {
        amber: "border-amber-200 bg-amber-50",
        rose: "border-rose-200 bg-rose-50",
        emerald: "border-emerald-200 bg-emerald-50",
        zinc: "border-zinc-200 bg-zinc-50",
        violet: "border-brand-200 bg-brand-50"
      }.fetch(tone, "border-amber-200 bg-amber-50")
    end

    def appointment_detail_action_text_classes(tone)
      {
        amber: "text-amber-950",
        rose: "text-rose-950",
        emerald: "text-emerald-950",
        zinc: "text-zinc-950",
        violet: "text-brand-700"
      }.fetch(tone, "text-amber-950")
    end

    def appointment_detail_action_body_classes(tone)
      {
        amber: "text-amber-800",
        rose: "text-rose-800",
        emerald: "text-emerald-800",
        zinc: "text-zinc-600",
        violet: "text-brand-700"
      }.fetch(tone, "text-amber-800")
    end

    def appointment_detail_deposit_card_classes(appointment)
      return "bg-zinc-50 text-zinc-700" unless appointment.deposit_required?
      return "bg-emerald-50 text-emerald-800" if appointment.deposit_status == "approved"
      return "bg-amber-50 text-amber-800" if appointment.deposit_status == "submitted"
      return "bg-rose-50 text-rose-800" if appointment.deposit_status.in?(%w[rejected failed])

      "bg-rose-50 text-rose-800"
    end

    def appointment_detail_event_dot_classes(event)
      case Admin::NotificationItem.new(event).tone
      when :emerald then "bg-emerald-500"
      when :amber then "bg-amber-500"
      when :rose then "bg-rose-500"
      when :sky then "bg-sky-500"
      else "bg-zinc-300"
      end
    end

    def appointment_detail_customer_label(customer, appointments_count)
      return "Cliente sin ficha" if customer.blank?
      return "Cliente frecuente" if appointments_count.to_i >= 3
      return "Primera vez" if appointments_count.to_i <= 1

      "Cliente recurrente"
    end

    private
      def appointment_deposit_submitted_for_review?(appointment)
        appointment.deposit_required? && appointment.deposit_status == "submitted" && !appointment.confirmed?
      end

      def appointment_deposit_pending?(appointment)
        appointment.deposit_required? && appointment.deposit_status.in?(%w[pending rejected failed]) && !appointment.confirmed?
      end
  end
end
