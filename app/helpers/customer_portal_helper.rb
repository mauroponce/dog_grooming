module CustomerPortalHelper
  PORTAL_SHORT_MONTHS = %w[ene feb mar abr may jun jul ago sep oct nov dic].freeze
  PORTAL_DAYS = %w[domingo lunes martes miércoles jueves viernes sábado].freeze

  def portal_money(cents)
    number_to_currency(cents.to_i / 100, unit: "$", precision: 0, delimiter: ".")
  end

  def portal_customer_first_name(customer_profile)
    customer_profile&.first_name.presence ||
      customer_profile&.name.to_s.split.first.presence ||
      "cliente"
  end

  def portal_customer_full_name(customer_profile)
    customer_profile&.name.presence || "Cliente"
  end

  def portal_customer_initials(customer_profile)
    portal_customer_full_name(customer_profile).split.first(2).map { |part| part.first&.upcase }.join.presence || "CL"
  end

  def portal_calendar_badge(appointment)
    time = appointment.starts_at.in_time_zone
    {
      month: PORTAL_SHORT_MONTHS.fetch(time.month - 1).capitalize,
      day: time.day.to_s.rjust(2, "0")
    }
  end

  def portal_appointment_date_label(appointment)
    time = appointment.starts_at.in_time_zone
    portal_time_label(time)
  end

  def portal_time_label(value)
    time = value.in_time_zone
    "#{PORTAL_DAYS.fetch(time.wday).capitalize} #{CustomerDateFormatter.date_label(time)} · #{time.strftime('%H:%M')}"
  end

  def portal_change_deadline_label(appointment)
    deadline = appointment.starts_at - appointment.business.rescheduling_notice_hours.hours
    "#{format_ar_date(deadline)} · #{deadline.in_time_zone.strftime('%H:%M')}"
  end

  def portal_duration_label(minutes)
    hours, remainder = minutes.to_i.divmod(60)
    parts = []
    parts << "#{hours} #{'hora'.pluralize(hours)}" if hours.positive?
    parts << "#{remainder} min" if remainder.positive?
    parts.presence&.join(" ") || "#{minutes.to_i} min"
  end

  def portal_price_label(cents)
    cents.to_i.zero? ? "Consultar" : portal_money(cents)
  end

  def portal_deposit_payment_label(appointment)
    return "Sin seña" unless appointment.deposit_required?
    return "Seña pagada por #{portal_deposit_payment_method_label(appointment)}: #{appointment.formatted_deposit_amount}" if appointment.deposit_status == "approved"
    return "Seña en revisión: #{appointment.formatted_deposit_amount}" if appointment.deposit_status == "submitted"

    "Seña pendiente: #{appointment.formatted_deposit_amount}"
  end

  def portal_remaining_balance_label(appointment)
    "Resta pagar en el local: #{appointment.formatted_remaining_balance}"
  end

  def portal_payment_tone_classes(appointment)
    return "text-zinc-600" unless appointment.deposit_required?
    return "text-emerald-700" if appointment.deposit_status == "approved"
    return "text-amber-700" if appointment.deposit_status == "submitted"

    "text-rose-700"
  end

  def portal_booking_again_path(business, service)
    short_public_service_path(business.slug, service.slug)
  end

  def portal_service_detail_line(appointment)
    parts = []
    show_professional = appointment.business.public_booking_allow_professional_selection?
    parts << "Con #{appointment.employee_membership.name}" if show_professional && appointment.employee_membership.present?
    duration = portal_duration_label(appointment.service.duration_minutes)
    parts << (show_professional ? duration : "Duración: #{duration}")
    parts.compact_blank.join(" · ")
  end

  def portal_professional_visible?(appointment)
    appointment.business.public_booking_allow_professional_selection?
  end

  def portal_deposit_payment_method_label(appointment)
    return "Mercado Pago" if appointment.payment_collection_method == "mercado_pago"

    "transferencia"
  end

  def portal_business_hours_rows(business)
    rules = business.availability_rules.order(:weekday).index_by(&:weekday)

    Business::DAYS.map do |weekday, day_name|
      rule = rules[weekday]
      {
        day_name: day_name.downcase,
        active: rule&.active?,
        label: if rule&.active? && rule.start_time.present? && rule.end_time.present?
                 "#{rule.start_time.strftime('%H:%M')} - #{rule.end_time.strftime('%H:%M')}"
               else
                 "Cerrado"
               end
      }
    end
  end

  def portal_favorite_service(history)
    counts = history.each_with_object(Hash.new { |hash, key| hash[key] = { service: nil, count: 0 } }) do |appointment, memo|
      next if appointment.service.blank?

      memo[appointment.service_id][:service] = appointment.service
      memo[appointment.service_id][:count] += 1
    end

    counts.values.max_by { |entry| entry[:count] }&.fetch(:service, nil)
  end

  def portal_booking_status_classes(appointment)
    case Appointment.status_tone(appointment.status)
    when :emerald
      "bg-emerald-50 text-emerald-700"
    when :amber
      "bg-amber-50 text-amber-700"
    when :rose
      "bg-rose-50 text-rose-700"
    else
      "bg-zinc-100 text-zinc-700"
    end
  end

  def portal_deposit_status_classes(appointment)
    case appointment.deposit_status
    when "approved"
      "bg-emerald-50 text-emerald-700"
    when "submitted"
      "bg-amber-50 text-amber-700"
    when "rejected", "failed"
      "bg-rose-50 text-rose-700"
    else
      "bg-zinc-100 text-zinc-700"
    end
  end

  def portal_appointment_location(appointment)
    appointment.branch&.name.presence || appointment.business.public_location
  end

  def portal_appointment_directions_url(appointment)
    location = appointment.branch || appointment.business
    destination = if location.geocoded?
      "#{location.latitude},#{location.longitude}"
    else
      location.public_location
    end
    destination = appointment.business.name if destination.blank? || destination == "Ubicación a confirmar"

    "https://www.google.com/maps/dir/?api=1&destination=#{CGI.escape(destination)}&travelmode=driving"
  end
end
