module Admin
  module CalendarHelper
    def admin_calendar_entry_classes(tone, appointment: false)
      base = "admin-calendar-booking border"
      tone_classes = {
        amber: "border-amber-200 bg-amber-50 text-amber-900",
        brand: "border-brand-200 bg-brand-50 text-brand-900",
        emerald: "border-emerald-200 bg-emerald-50 text-emerald-900",
        rose: "border-rose-200 bg-rose-50 text-rose-900",
        sky: "border-sky-200 bg-sky-50 text-sky-900",
        zinc: "border-zinc-200 bg-zinc-100 text-zinc-700"
      }.fetch(tone, "border-zinc-200 bg-zinc-100 text-zinc-700")
      appointment_class = appointment ? "admin-calendar-appointment-link" : nil
      [ base, tone_classes, appointment_class ].compact.join(" ")
    end

    def admin_calendar_entry_meta_classes(tone)
      {
        amber: "text-amber-700",
        brand: "text-brand-700",
        emerald: "text-emerald-700",
        rose: "text-rose-700",
        sky: "text-sky-700",
        zinc: "text-zinc-600"
      }.fetch(tone, "text-zinc-600")
    end

    def admin_calendar_month_day_classes(day)
      base = "month-day block border-r border-t border-zinc-100 p-3 text-left transition hover:bg-zinc-50"
      state = []
      state << "bg-brand-50" if day.selected
      state << "bg-zinc-50/60 text-zinc-400" unless day.current_month
      state << "ring-2 ring-inset ring-brand-200" if day.today
      "#{base} #{state.join(' ')}"
    end

    def admin_calendar_week_day_classes(day)
      base = "block rounded-[28px] border border-zinc-100 bg-white p-4 text-left shadow-soft transition hover:-translate-y-0.5 hover:border-brand-200 hover:shadow-card"
      state = []
      state << "ring-2 ring-inset ring-brand-200" if day.selected
      state << "bg-brand-50" if day.today
      "#{base} #{state.join(' ')}"
    end

    def admin_calendar_attention_classes(tone)
      {
        amber: "border-amber-100 bg-amber-50 text-amber-900",
        rose: "border-rose-100 bg-rose-50 text-rose-900",
        sky: "border-sky-100 bg-sky-50 text-sky-900",
        green: "border-emerald-100 bg-emerald-50 text-emerald-900",
        emerald: "border-emerald-100 bg-emerald-50 text-emerald-900"
      }.fetch(tone, "border-zinc-200 bg-zinc-50 text-zinc-900")
    end

    def admin_calendar_urgency_pill_classes(pill)
      active_classes = {
        amber: "border-amber-200 bg-amber-50 text-amber-700 hover:bg-amber-100",
        rose: "border-rose-200 bg-rose-50 text-rose-700 hover:bg-rose-100",
        sky: "border-sky-200 bg-sky-50 text-sky-700 hover:bg-sky-100",
        zinc: "border-zinc-200 bg-zinc-50 text-zinc-500"
      }.fetch(pill.tone, "border-zinc-200 bg-zinc-50 text-zinc-500")

      base = "inline-flex h-11 items-center justify-center gap-2 rounded-2xl border px-4 text-sm font-bold transition"
      "#{base} #{active_classes}"
    end
  end
end
