module Admin
  module ServicesHelper
    def service_metric_hint_classes(tone)
      {
        green: "bg-emerald-50 text-emerald-700",
        violet: "bg-brand-50 text-brand-700",
        amber: "bg-amber-50 text-amber-700",
        rose: "bg-rose-50 text-rose-700",
        zinc: "bg-zinc-100 text-zinc-600"
      }.fetch(tone, "bg-zinc-100 text-zinc-600")
    end

    def service_status_classes(label)
      case label
      when "Activo", "Público", "Popular"
        "bg-emerald-50 text-emerald-700"
      when "Requiere seña", "Con seña", "Completar"
        "bg-amber-50 text-amber-700"
      when "Oculto", "Archivado", "Privado", "Pausado"
        "bg-zinc-100 text-zinc-600"
      when "Solo por link"
        "bg-brand-50 text-brand-700"
      else
        "bg-zinc-100 text-zinc-600"
      end
    end

    def service_card_classes(service, selected)
      base = "rounded-lg border bg-white p-4 transition"
      return "#{base} border-brand-300 bg-brand-50/70 shadow-sm" if selected
      return "#{base} border-amber-200 bg-amber-50/60" if service.incomplete?
      return "#{base} border-zinc-200 bg-zinc-50 opacity-80" if service.hidden? || service.archived?

      "#{base} border-zinc-200 hover:border-brand-200 hover:bg-brand-50/25"
    end

    def service_filter_classes(active)
      if active
        "border-ink bg-ink text-white shadow-lg shadow-zinc-900/10"
      else
        "border-zinc-200 bg-white text-zinc-800 hover:bg-zinc-50"
      end
    end

    def service_money(cents)
      number_to_currency(cents.to_i / 100, unit: "$", precision: 0, delimiter: ".")
    end

    def service_duration_label(minutes)
      value = minutes.to_i
      hours = value / 60
      remaining_minutes = value % 60

      return "#{value} min" if hours.zero?
      return "#{hours} h" if remaining_minutes.zero?

      "#{hours} h y #{remaining_minutes} min"
    end

    def service_public_link_enabled?(service)
      service.complete? && service.active? && service.visibility_mode.in?(%w[public link_only])
    end

    def service_public_action_path(service)
      if service_public_link_enabled?(service)
        short_public_service_path(service.business.slug, service.slug)
      else
        admin_services_path(service_id: service.id)
      end
    end

    def admin_public_service_url(service)
      return "" if service.blank? || service.business.blank? || service.slug.blank?

      current_public_service_url(service)
    end

    def service_status_labels(service)
      labels = []
      labels << (service.active? && service.archived_at.blank? ? "Activo" : "Pausado")
      labels << if service.public?
        "Público"
      elsif service.link_only?
        "Solo por link"
      elsif service.archived?
        "Archivado"
      else
        "Privado"
      end
      labels << "Completar" if service.incomplete?
      labels
    end

    def service_team_label(service, business)
      return "Agenda principal" unless business.team_features_available?

      count = service.employee_memberships.size
      return "Todo el equipo" if count.zero?

      "#{count} #{count == 1 ? "profesional" : "profesionales"}"
    end

    def service_resource_label(service)
      resource = service.bookable_resources.first
      return "Sin recurso" if resource.blank?

      service.bookable_resources.size == 1 ? "Recurso: #{resource.name}" : "#{service.bookable_resources.size} recursos"
    end

    def service_improvement_classes(tone)
      {
        amber: "bg-amber-50 text-amber-950 border-amber-100",
        brand: "bg-brand-50 text-brand-950 border-brand-100",
        green: "bg-emerald-50 text-emerald-950 border-emerald-100"
      }.fetch(tone, "bg-zinc-50 text-zinc-950 border-zinc-100")
    end

    def service_improvement_label_classes(tone)
      {
        amber: "text-amber-700",
        brand: "text-brand-700",
        green: "text-emerald-700"
      }.fetch(tone, "text-zinc-500")
    end

    def service_public_state_label(service)
      return "Activo" if service.public?
      return "Solo por link" if service.link_only?
      return "Archivado" if service.archived?
      return "Completar" if service.incomplete?

      "Privado"
    end

    def service_short_date(date)
      date.strftime("%d/%m/%Y")
    end

    def service_booking_short_label(appointment)
      "#{appointment.starts_at.strftime("%d/%m · %H:%M")} · #{appointment.status_label.downcase}"
    end

    def service_visibility_options
      [
        [ "Público", "public" ],
        [ "Oculto", "hidden" ],
        [ "Solo por link", "link_only" ]
      ]
    end

    def service_deposit_deadline_options
      [
        [ "15 minutos", 15 ],
        [ "30 minutos", 30 ],
        [ "60 minutos", 60 ],
        [ "2 horas", 120 ],
        [ "24 horas", 1_440 ]
      ]
    end

    def service_professional_selection_options
      [
        [ "No mostrar profesionales, asignar automáticamente", "hidden" ],
        [ "Permitir elegir profesional", "optional" ],
        [ "Obligar a elegir profesional", "required" ]
      ]
    end

    def service_public_start_interval_options
      [
        [ "Automático recomendado", nil ],
        [ "Cada 15 minutos", 15 ],
        [ "Cada 30 minutos", 30 ],
        [ "Cada 60 minutos", 60 ]
      ]
    end

    def service_incomplete_reasons(service)
      reasons = []
      reasons << "nombre" if service.name.blank?
      reasons << "descripción" if service.description.blank?
      reasons << "duración" if service.duration_minutes.blank?
      reasons << "precio" unless service.price_cents.to_i.positive?
      reasons
    end
  end
end
