module Admin
  module CustomerProfilesHelper
    DIRECTORY_SHORT_MONTHS = %w[ene feb mar abr may jun jul ago sep oct nov dic].freeze

    def customer_metric_hint_classes(tone)
      {
        violet: "bg-brand-50 text-brand-700",
        green: "bg-emerald-50 text-emerald-700",
        amber: "bg-amber-50 text-amber-700",
        rose: "bg-rose-50 text-rose-700",
        zinc: "bg-zinc-100 text-zinc-600"
      }.fetch(tone, "bg-zinc-100 text-zinc-600")
    end

    def customer_status_chip_classes(tone)
      {
        violet: "bg-brand-50 text-brand-700",
        green: "bg-emerald-50 text-emerald-700",
        amber: "bg-amber-50 text-amber-700",
        rose: "bg-rose-50 text-rose-700",
        zinc: "bg-zinc-100 text-zinc-600"
      }.fetch(tone, "bg-zinc-100 text-zinc-600")
    end

    def customer_filter_classes(active, key)
      return "inline-flex h-11 items-center justify-center rounded-2xl bg-ink px-4 text-sm font-bold text-white" if active

      {
        "frequent" => "inline-flex h-11 items-center justify-center rounded-2xl border border-emerald-200 bg-emerald-50 px-4 text-sm font-bold text-emerald-700 transition hover:bg-emerald-100",
        "new" => "inline-flex h-11 items-center justify-center rounded-2xl border border-emerald-200 bg-emerald-50 px-4 text-sm font-bold text-emerald-700 transition hover:bg-emerald-100",
        "pending_deposit" => "inline-flex h-11 items-center justify-center rounded-2xl border border-rose-200 bg-rose-50 px-4 text-sm font-bold text-rose-700 transition hover:bg-rose-100"
      }.fetch(key.to_s, "inline-flex h-11 items-center justify-center rounded-2xl border border-zinc-200 bg-white px-4 text-sm font-bold text-zinc-700 transition hover:bg-zinc-50")
    end

    def customer_card_classes(profile, selected)
      base = "rounded-lg border bg-white p-4 transition"
      return "#{base} border-brand-300 bg-brand-50/70 shadow-sm" if selected
      return "#{base} border-rose-200 bg-rose-50/60" if profile.no_show_previous? || profile.pending_deposit?
      "#{base} border-zinc-200 hover:border-brand-200 hover:bg-brand-50/25"
    end

    def customer_avatar_classes(profile)
      return "bg-rose-50 text-rose-700" if profile.no_show_previous? || profile.pending_deposit?
      return "bg-brand-600 text-white" if profile.frequent?

      "bg-zinc-100 text-zinc-700"
    end

    def customer_table_avatar_classes(profile)
      return "bg-rose-500 text-white" if profile.no_show_previous? || profile.pending_deposit?
      return "bg-emerald-600 text-white" if profile.frequent? || profile.new_customer?

      "bg-zinc-900 text-white"
    end

    def customer_table_card_classes(profile)
      return "border-rose-200 bg-white" if profile.no_show_previous? || profile.pending_deposit?
      return "border-emerald-200 bg-white" if profile.frequent? || profile.new_customer?

      "border-white bg-white"
    end

    def customer_table_segment_chip(profile)
      profile.status_chips.first
    end

    def customer_operational_chip(profile)
      if profile.pending_deposit?
        Customers::ProfilePresenter::StatusChip.new(label: "Seña pendiente", tone: :rose)
      elsif profile.no_show_previous?
        Customers::ProfilePresenter::StatusChip.new(label: "Revisar historial", tone: :rose)
      else
        Customers::ProfilePresenter::StatusChip.new(label: "Sin deuda", tone: :zinc)
      end
    end

    def customer_last_visit_text(profile)
      profile.last_visit.present? ? CustomerDateFormatter.date_label(profile.last_visit.starts_at) : "Sin visitas"
    end

    def customer_frequent_service_text(profile)
      profile.preferred_service&.name || "Sin servicio"
    end

    def customer_frequent_employee_text(profile)
      profile.preferred_employee&.name || "Sin profesional"
    end

    def customer_directory_initial(profile)
      profile.initials.to_s.first.presence || "?"
    end

    def customer_directory_created_on(customer)
      return "-" if customer.created_at.blank?

      date = customer.created_at.in_time_zone
      "#{date.day} #{DIRECTORY_SHORT_MONTHS.fetch(date.month - 1)}. #{date.year}"
    end

    def customer_directory_created_short(customer)
      return "-" if customer.created_at.blank?

      customer.created_at.in_time_zone.strftime("%d/%m")
    end

    def customer_directory_client_summary(profile, customer)
      "Cliente desde #{customer_directory_created_short(customer)}"
    end

    def customer_directory_reference_appointment(profile)
      profile.next_appointment || profile.last_visit || profile.appointments.reject(&:canceled?).max_by(&:starts_at)
    end

    def customer_directory_turn_label(profile)
      appointment = customer_directory_reference_appointment(profile)
      return "Sin turnos" if appointment.blank?

      prefix = appointment == profile.next_appointment ? "Próximo" : "Último"
      time = appointment.starts_at.in_time_zone
      "#{prefix}: #{time.strftime('%d/%m')} · #{time.strftime('%H:%M')}"
    end

    def customer_directory_turn_service(profile)
      customer_directory_reference_appointment(profile)&.service&.name || "Sin turno registrado"
    end

    def customer_directory_turn_status(profile)
      appointment = customer_directory_reference_appointment(profile)
      return [ "Sin turnos", "Sin seña" ] if appointment.blank?

      [ appointment.status_label, customer_directory_deposit_label(appointment) ]
    end

    def customer_directory_deposit_label(appointment)
      case appointment.deposit_status
      when "pending"
        "Seña pendiente"
      when "submitted"
        "Comprobante en revisión"
      when "rejected", "failed"
        "Revisar seña"
      else
        "Seña al día"
      end
    end

    def customer_directory_sales_label(profile)
      cents = profile.appointments.reject(&:canceled?).sum { |appointment| appointment.final_price_cents.to_i }
      number_to_currency(cents / 100.0, unit: "$", precision: cents % 100 == 0 ? 0 : 2, delimiter: ".", separator: ",")
    end

    def customer_directory_turn_count_label(profile)
      count = profile.appointments.reject(&:canceled?).count
      "#{count} #{count == 1 ? 'turno' : 'turnos'}"
    end

    def customer_detail_metric_classes(tone)
      {
        green: "bg-emerald-50 text-emerald-950",
        amber: "bg-amber-50 text-amber-950",
        rose: "bg-rose-50 text-rose-950",
        sky: "bg-sky-50 text-sky-950",
        violet: "bg-brand-50 text-brand-700",
        zinc: "bg-zinc-50 text-zinc-950"
      }.fetch(tone, "bg-zinc-50 text-zinc-950")
    end

    def customer_detail_panel_classes(tone)
      {
        green: "border-emerald-200 bg-emerald-50",
        amber: "border-amber-200 bg-amber-50",
        rose: "border-rose-200 bg-rose-50",
        sky: "border-sky-200 bg-sky-50",
        violet: "border-brand-200 bg-brand-50",
        zinc: "border-zinc-200 bg-zinc-50"
      }.fetch(tone, "border-zinc-200 bg-zinc-50")
    end

    def customer_detail_text_classes(tone)
      {
        green: "text-emerald-950",
        amber: "text-amber-950",
        rose: "text-rose-950",
        sky: "text-sky-950",
        violet: "text-brand-700",
        zinc: "text-zinc-950"
      }.fetch(tone, "text-zinc-950")
    end

    def customer_detail_body_classes(tone)
      {
        green: "text-emerald-800",
        amber: "text-amber-800",
        rose: "text-rose-800",
        sky: "text-sky-800",
        violet: "text-brand-700",
        zinc: "text-zinc-600"
      }.fetch(tone, "text-zinc-600")
    end

    def customer_detail_money(cents)
      amount = cents.to_i / 100.0
      precision = cents.to_i % 100 == 0 ? 0 : 2
      number_to_currency(amount, unit: "$", precision:, delimiter: ".", separator: ",")
    end

    def customer_detail_frequency_label(profile)
      return "Sin datos suficientes" if profile.total_appointments < 2
      return "Cliente frecuente" if profile.frequent?

      "Cliente recurrente"
    end

    def customer_detail_contact_source(profile)
      "Fuente: #{profile.source_label}"
    end

    def customer_segment_classes(tone)
      {
        violet: "border-brand-200 bg-brand-50 hover:bg-brand-100",
        amber: "border-amber-200 bg-amber-50 hover:bg-amber-100",
        rose: "border-rose-200 bg-rose-50 hover:bg-rose-100",
        sky: "border-sky-200 bg-sky-50 hover:bg-sky-100"
      }.fetch(tone, "border-zinc-200 bg-zinc-50 hover:bg-zinc-100")
    end

    def customer_opportunity_button_classes(tone)
      {
        violet: "bg-brand-600 hover:bg-brand-700",
        amber: "bg-amber-600 hover:bg-amber-700",
        rose: "bg-rose-600 hover:bg-rose-700",
        sky: "bg-sky-600 hover:bg-sky-700"
      }.fetch(tone, "bg-zinc-950 hover:bg-zinc-800")
    end

    def customer_appointment_status_classes(appointment)
      "customer-status-#{customer_appointment_status_tone(appointment)}"
    end

    def customer_appointment_status_label(appointment)
      case customer_appointment_effective_status(appointment)
      when "confirmed" then "Confirmado"
      when "pending_deposit_review" then "Seña pendiente de aprobación"
      when "canceled" then "Cancelado"
      when "completed" then "Finalizado"
      else appointment.status_label
      end
    end

    def customer_appointment_effective_status(appointment)
      return "completed" if appointment.confirmed? && appointment.ends_at.present? && appointment.ends_at <= Time.current

      appointment.status
    end

    def customer_appointment_status_tone(appointment)
      case customer_appointment_effective_status(appointment)
      when "confirmed" then "green"
      when "pending_deposit_review" then "amber"
      when "canceled", "pending_deposit", "deposit_rejected", "pending_payment", "no_show" then "red"
      when "completed" then "violet"
      else "zinc"
      end
    end
  end
end
