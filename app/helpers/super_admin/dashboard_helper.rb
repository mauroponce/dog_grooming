module SuperAdmin::DashboardHelper
  def super_admin_money(cents)
    number_to_currency(cents.to_i / 100, unit: "$", precision: 0, delimiter: ".", separator: ",")
  end

  def super_admin_storage(bytes)
    number_to_human_size(bytes.to_i)
  end

  def super_admin_status_classes(row)
    {
      "active" => "bg-emerald-50 text-emerald-700",
      "trial" => "bg-brand-50 text-brand-700",
      "pending_review" => "bg-brand-50 text-brand-700",
      "overdue" => "bg-rose-50 text-rose-700",
      "restricted" => "bg-amber-50 text-amber-700",
      "free" => "bg-emerald-50 text-emerald-700",
      "needs_setup" => "bg-amber-50 text-amber-700",
      "disabled" => "bg-zinc-100 text-zinc-700"
    }.fetch(row.status_key, "bg-zinc-100 text-zinc-700")
  end

  def super_admin_setup_bar_classes(score)
    return "bg-emerald-500" if score >= 85
    return "bg-brand-500" if score >= 60

    "bg-amber-500"
  end

  def super_admin_filter_classes(active)
    if active
      "h-11 rounded-2xl bg-ink px-4 text-xs font-bold text-white"
    else
      "h-11 rounded-2xl border border-zinc-200 bg-white px-4 text-xs font-bold text-zinc-700 transition hover:bg-zinc-50"
    end
  end

  def super_admin_metric_badge_classes(tone)
    {
      emerald: "bg-emerald-50 text-emerald-700",
      amber: "bg-amber-50 text-amber-700",
      rose: "bg-rose-50 text-rose-700",
      brand: "bg-brand-50 text-brand-700",
      zinc: "bg-zinc-100 text-zinc-700",
      sky: "bg-sky-50 text-sky-700"
    }.fetch(tone, "bg-zinc-100 text-zinc-700")
  end

  def super_admin_attention_classes(tone)
    {
      amber: "border-amber-100 bg-amber-50",
      rose: "border-rose-100 bg-rose-50",
      sky: "border-sky-100 bg-sky-50",
      brand: "border-brand-100 bg-brand-50",
      emerald: "border-emerald-100 bg-emerald-50"
    }.fetch(tone, "border-zinc-100 bg-zinc-50")
  end

  def super_admin_dot_classes(tone)
    {
      emerald: "bg-emerald-500",
      amber: "bg-amber-500",
      rose: "bg-rose-500",
      brand: "bg-brand-500",
      sky: "bg-sky-500",
      zinc: "bg-zinc-400"
    }.fetch(tone, "bg-zinc-400")
  end

  def super_admin_system_value_classes(tone)
    {
      emerald: "text-emerald-700",
      amber: "text-amber-700",
      rose: "text-rose-700",
      brand: "text-brand-700",
      zinc: "text-zinc-500"
    }.fetch(tone, "text-zinc-500")
  end

  def super_admin_time_ago(time)
    return "sin actividad" if time.blank?

    "hace #{time_ago_in_words(time)}"
  end

  def super_admin_registration_date(time)
    return "Sin fecha" if time.blank?

    time.strftime("%d/%m/%Y")
  end

  def super_admin_business_system_label(row)
    row.failed_email_count.positive? || row.restricted? || row.disabled? ? "Atención" : "OK"
  end

  def super_admin_business_system_classes(row)
    super_admin_business_system_label(row) == "OK" ? "bg-emerald-50 text-emerald-700" : "bg-amber-50 text-amber-700"
  end

  def super_admin_public_business_url(business)
    PublicLinks::UrlBuilder.business(business)
  end
end
