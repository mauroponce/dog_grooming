module PublicBookingHelper
  SPANISH_DAYS = %w[domingo lunes martes miercoles jueves viernes sabado].freeze
  SPANISH_MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze
  DOG_BREEDS = [
    "Affenpinscher", "Airedale Terrier", "Akita Inu", "Alaskan Malamute", "American Bully", "American Staffordshire Terrier", "Basenji", "Basset Hound", "Beagle", "Bearded Collie", "Bedlington Terrier", "Bernés de la montaña", "Bichón Frisé", "Bichón Habanero", "Bloodhound", "Bobtail", "Border Collie", "Border Terrier", "Boston Terrier", "Bóxer", "Boyero de Berna", "Braco Alemán", "Braco Húngaro", "Bull Terrier", "Bulldog Francés", "Bulldog Inglés", "Bullmastiff", "Cane Corso", "Caniche", "Caniche Toy", "Cavalier King Charles Spaniel", "Chihuahua", "Chow Chow", "Cocker Spaniel Americano", "Cocker Spaniel Inglés", "Collie", "Corgi Galés Pembroke", "Dachshund", "Dálmata", "Doberman", "Dogo Argentino", "Dogo de Burdeos", "English Springer Spaniel", "Galgo", "Golden Retriever", "Gran Danés", "Husky Siberiano", "Jack Russell Terrier", "Labrador Retriever", "Lebrel Afgano", "Maltés", "Mastín Español", "Mastín Napolitano", "Mestizo", "Miniature Pinscher", "Münsterländer", "Papillón", "Pastor Alemán", "Pastor Australiano", "Pastor Belga", "Pastor Blanco Suizo", "Pastor de Shetland", "Pastor Inglés", "Pekinés", "Perro de Agua Español", "Pinscher Miniatura", "Pit Bull Terrier", "Pointer", "Pomerania", "Poodle", "Pug", "Rottweiler", "Sabueso", "Samoyedo", "San Bernardo", "Schnauzer", "Schnauzer Miniatura", "Setter Inglés", "Shar Pei", "Shiba Inu", "Shih Tzu", "Staffordshire Bull Terrier", "Teckel", "Terranova", "Terrier Escocés", "Terrier Yorkshire", "Weimaraner", "West Highland White Terrier", "Whippet", "Yorkshire Terrier"
  ].sort.freeze

  def public_icon(name, css: "h-5 w-5")
    icons = {
      "nails" => '<path d="M8 21c-2.2-1.5-3.5-3.8-3.5-6.5V8.8a1.8 1.8 0 0 1 3.6 0V12"/><path d="M8.1 11V5.8a1.8 1.8 0 0 1 3.6 0V11"/><path d="M11.7 10V5a1.8 1.8 0 0 1 3.6 0v6"/><path d="M15.3 10V6.2a1.8 1.8 0 0 1 3.6 0v7.3c0 4.6-2.7 7.5-6.9 7.5H8Z"/>',
      "face" => '<circle cx="12" cy="12" r="9"/><path d="M8.5 10h.01M15.5 10h.01M8.5 15c1.7 1.5 5.3 1.5 7 0"/><path d="M8 4.2c.9 1.5 2.2 2.4 4 2.4s3.1-.9 4-2.4"/>',
      "spark" => '<path d="M12 3c1.9 3.2 4.1 5.1 7 6-2.9.9-5.1 2.8-7 6-1.9-3.2-4.1-5.1-7-6 2.9-.9 5.1-2.8 7-6Z"/><path d="M5 15c.9 1.6 2 2.6 3.5 3.1C7 18.6 5.9 19.6 5 21c-.9-1.4-2-2.4-3.5-2.9C3 17.6 4.1 16.6 5 15Z"/>',
      "flash" => '<path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z"/>',
      "health" => '<path d="M12 21s-7-4.5-9-10a5.2 5.2 0 0 1 9-5 5.2 5.2 0 0 1 9 5c-2 5.5-9 10-9 10Z"/><path d="M9 12h6M12 9v6"/>',
      "scissors" => '<circle cx="6" cy="7" r="3"/><circle cx="6" cy="17" r="3"/><path d="M8.6 8.8 20 4M8.6 15.2 20 20M9 12h3"/>',
      "home" => '<path d="m4 11 8-7 8 7"/><path d="M6 10.5V20h12v-9.5"/><path d="M10 20v-5h4v5"/>',
      "users" => '<path d="M16 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2"/><circle cx="9.5" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
      "list" => '<path d="M8 6h13M8 12h13M8 18h13"/><path d="M3 6h.01M3 12h.01M3 18h.01"/>',
      "cart" => '<path d="M3 4h2l2.4 11.2a2 2 0 0 0 2 1.6h7.8a2 2 0 0 0 1.9-1.4L21 8H6"/><circle cx="10" cy="20" r="1"/><circle cx="18" cy="20" r="1"/>',
      "receipt" => '<path d="M5 3h14v18l-2-1-2 1-2-1-2 1-2-1-2 1-2-1V3Z"/><path d="M8 7h8M8 11h8M8 15h5"/>',
      "settings" => '<path d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z"/><path d="M19.4 15a1.8 1.8 0 0 0 .36 1.98l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06A1.8 1.8 0 0 0 15 19.4a1.8 1.8 0 0 0-1 .6 1.8 1.8 0 0 0-.4 1.2V21a2 2 0 0 1-4 0v-.1a1.8 1.8 0 0 0-.4-1.2 1.8 1.8 0 0 0-1-.6 1.8 1.8 0 0 0-1.98.36l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.8 1.8 0 0 0 4.6 15a1.8 1.8 0 0 0-.6-1 1.8 1.8 0 0 0-1.2-.4H3a2 2 0 0 1 0-4h.1a1.8 1.8 0 0 0 1.2-.4 1.8 1.8 0 0 0 .6-1 1.8 1.8 0 0 0-.36-1.98l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.8 1.8 0 0 0 9 4.6a1.8 1.8 0 0 0 1-.6 1.8 1.8 0 0 0 .4-1.2V3a2 2 0 0 1 4 0v.1a1.8 1.8 0 0 0 .4 1.2 1.8 1.8 0 0 0 1 .6 1.8 1.8 0 0 0 1.98-.36l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.8 1.8 0 0 0 19.4 9c.3.3.7.5 1.1.6H21a2 2 0 0 1 0 4h-.1a1.8 1.8 0 0 0-1.2.4 1.8 1.8 0 0 0-.3 1Z"/>',
      "calendar" => '<path d="M4 7h16M6 3v4M18 3v4M5 5h14a1 1 0 0 1 1 1v14H4V6a1 1 0 0 1 1-1Z"/><path d="m8.5 14 2 2 5-5"/>',
      "bell" => '<path d="M18 8a6 6 0 1 0-12 0c0 7-3 7-3 7h18s-3 0-3-7"/><path d="M10 19a2 2 0 0 0 4 0"/>',
      "clock" => '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
      "pin" => '<path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>',
      "shield" => '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/>',
      "warning" => '<path d="m12 3 10 18H2L12 3Z"/><path d="M12 9v5M12 17h.01"/>',
      "search" => '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
      "arrow_right" => '<path d="m9 18 6-6-6-6"/>',
      "arrow_left" => '<path d="m15 18-6-6 6-6"/>',
      "check" => '<path d="m5 12 4 4L19 6"/>',
      "close" => '<path d="M6 6l12 12M18 6 6 18"/>',
      "heart" => '<path d="M20.8 4.6a5.4 5.4 0 0 0-7.6 0L12 5.8l-1.2-1.2a5.4 5.4 0 0 0-7.6 7.6L12 21l8.8-8.8a5.4 5.4 0 0 0 0-7.6Z"/>',
      "share" => '<path d="M4 12v7a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-7"/><path d="M12 3v12"/><path d="m7 8 5-5 5 5"/>',
      "copy" => '<rect x="8" y="8" width="11" height="11" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
      "message" => '<path d="M6 8h12M6 12h8M6 16h5"/><rect x="3" y="4" width="18" height="16" rx="2"/>'
    }

    tag.svg(
      icons.fetch(name, icons.fetch("calendar")).html_safe,
      viewBox: "0 0 24 24",
      class: css,
      fill: "none",
      stroke: "currentColor",
      stroke_width: "1.8",
      aria: { hidden: true }
    )
  end

  def public_date_label(date)
    "#{SPANISH_DAYS.fetch(date.wday).capitalize} #{CustomerDateFormatter.date_label(date)}"
  end

  def public_short_date_label(date)
    day = %w[dom lun mar mie jue vie sab].fetch(date.wday)
    month = SPANISH_MONTHS.fetch(date.month - 1).first(3)
    "#{day}, #{date.day} #{month}"
  end

  def public_month_label(date)
    "#{SPANISH_MONTHS.fetch(date.month - 1).capitalize} #{date.year}"
  end

  def service_price_label(service)
    service.price_cents.zero? ? "Consultar" : number_to_currency(service.price_cents / 100, unit: "$", precision: 0, delimiter: ".")
  end

  def price_cents_label(cents)
    cents.to_i.zero? ? "Consultar" : number_to_currency(cents.to_i / 100, unit: "$", precision: 0, delimiter: ".")
  end

  def public_service_duration_label(minutes)
    minutes = minutes.to_i
    hours = minutes / 60
    remainder = minutes % 60
    parts = []
    parts << "#{hours} h" if hours.positive?
    parts << "#{remainder} min" if remainder.positive?
    parts.presence&.join(" ") || "#{minutes} min"
  end

  def public_service_price_ars(service, prefix: false)
    return "Consultar" if service.price_cents.to_i.zero?

    amount = number_to_currency(service.price_cents / 100, unit: "$", precision: 0, delimiter: ".")
    amount
  end

  def public_business_hours_status(business)
    active_rules = business.availability_rules.select(&:active?)
    return { state: "Horarios", tone: "text-zinc-700", detail: "a confirmar" } if active_rules.blank?

    now = Time.zone.now
    today_rules = active_rules.select { |rule| rule.weekday == now.wday }.sort_by(&:start_time)
    current_seconds = now.seconds_since_midnight

    current_rule = today_rules.find do |rule|
      rule.start_time.seconds_since_midnight <= current_seconds && rule.end_time.seconds_since_midnight > current_seconds
    end
    if current_rule.present?
      return { state: "Abierto", tone: "text-emerald-600", detail: "hasta las #{current_rule.end_time.strftime('%H:%M')}" }
    end

    next_today = today_rules.find { |rule| rule.start_time.seconds_since_midnight > current_seconds }
    if next_today.present?
      return { state: "Cerrado", tone: "text-red-500", detail: "abre a las #{next_today.start_time.strftime('%H:%M')}" }
    end

    1.upto(7) do |offset|
      weekday = (now.wday + offset) % 7
      rule = active_rules.select { |item| item.weekday == weekday }.min_by(&:start_time)
      next if rule.blank?

      return {
        state: "Cerrado",
        tone: "text-red-500",
        detail: "abre #{SPANISH_DAYS.fetch(weekday)} a las #{rule.start_time.strftime('%H:%M')}"
      }
    end

    { state: "Cerrado", tone: "text-red-500", detail: "sin próximos horarios" }
  end

  def public_professional_photo(professional)
    photo = professional.effective_profile_photo
    return photo if photo.attached?

    nil
  end

  def public_business_osm_embed_url(business)
    return if business.blank? || !business.geocoded?

    latitude = business.latitude.to_f
    longitude = business.longitude.to_f
    delta = 0.0035
    bbox = [
      longitude - delta,
      latitude - delta,
      longitude + delta,
      latitude + delta
    ].join(",")

    "https://www.openstreetmap.org/export/embed.html?bbox=#{CGI.escape(bbox)}&layer=mapnik&marker=#{CGI.escape("#{latitude},#{longitude}")}"
  end

  def public_business_hours_rows(business)
    rules_by_weekday = business.availability_rules.index_by(&:weekday)

    Business::DAYS.map do |weekday, label|
      rule = rules_by_weekday[weekday]
      if rule&.active? && rule.start_time.present? && rule.end_time.present?
        { weekday: weekday, label: label.downcase, open: true, time: "#{rule.start_time.strftime('%H:%M')} - #{rule.end_time.strftime('%H:%M')}" }
      else
        { weekday: weekday, label: label.downcase, open: false, time: "Cerrado" }
      end
    end
  end
end
