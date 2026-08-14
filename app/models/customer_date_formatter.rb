class CustomerDateFormatter
  MONTHS = [
    nil,
    "Enero",
    "Febrero",
    "Marzo",
    "Abril",
    "Mayo",
    "Junio",
    "Julio",
    "Agosto",
    "Septiembre",
    "Octubre",
    "Noviembre",
    "Diciembre"
  ].freeze

  def self.appointment_label(value)
    return "" if value.blank?

    time = value.in_time_zone

    "#{date_label(time)} · #{time.strftime('%H:%M')} hs"
  end

  def self.date_label(value)
    return "" if value.blank?

    value.in_time_zone.strftime("%d/%m/%Y")
  end

  def self.datetime_label(value)
    return "" if value.blank?

    "#{date_label(value)} #{time_label(value)}"
  end

  def self.time_label(value)
    return "" if value.blank?

    "#{value.in_time_zone.strftime('%H:%M')} hs"
  end
end
