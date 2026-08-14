module Resources
  class ProfilePresenter
    attr_reader :resource, :business

    def initialize(resource:, business:)
      @resource = resource
      @business = business
    end

    def services_using_resource
      @services_using_resource ||= resource.service_resources.includes(:service).order("services.active DESC", "services.name ASC").to_a
    end

    def today_appointments
      @today_appointments ||= resource.appointments.includes(:service, :customer_profile, employee_membership: :user)
        .where(starts_at: today_range)
        .order(:starts_at)
        .to_a
    end

    def active_today_appointments
      today_appointments.reject(&:canceled?)
    end

    def today_blocks
      @today_blocks ||= resource.resource_blocks.active.overlapping(today_range.begin, today_range.end).order(:starts_at).to_a
    end

    def current_appointments
      @current_appointments ||= active_today_appointments.select { |appointment| appointment.starts_at <= now && appointment.ends_at > now }
    end

    def current_blocks
      @current_blocks ||= today_blocks.select { |block| block.starts_at <= now && block.ends_at > now }
    end

    def service_summary
      categories = services_using_resource.map { |requirement| requirement.service.category_label }.uniq
      categories.presence&.first(3)&.join(" / ") || "sin servicios asociados"
    end

    def next_occupation_label
      next_item = (active_today_appointments + today_blocks).select { |item| item.starts_at > now }.min_by(&:starts_at)
      return "Sin ocupación próxima" if next_item.blank?

      "#{CustomerDateFormatter.time_label(next_item.starts_at)} - #{CustomerDateFormatter.time_label(next_item.ends_at).delete_suffix(' hs')}"
    end

    def availability_label
      return "Archivado" if resource.archived?
      return "Inactivo" unless resource.active?
      return "Mantenimiento" if resource.status == "maintenance"
      return "Bloqueado" if current_blocks.any?
      return "Ocupado" if available_units_now.zero?
      return "Disponible parcial" if available_units_now < resource.quantity.to_i

      "Disponible"
    end

    def availability_detail
      return "No se muestra en disponibilidad pública." if resource.archived? || !resource.active?
      return "Bloqueado por mantenimiento." if resource.status == "maintenance"
      return "Hasta #{CustomerDateFormatter.time_label(occupied_until)}." if occupied_until.present? && available_units_now.zero?
      return "#{available_units_now} de #{resource.quantity} unidades libres." if resource.quantity.to_i > 1

      "Listo para reservar."
    end

    def availability_tone
      case availability_label
      when "Disponible" then :green
      when "Disponible parcial" then :sky
      when "Mantenimiento", "Bloqueado" then :amber
      when "Ocupado" then :rose
      else :zinc
      end
    end

    def available_units_now
      @available_units_now ||= begin
        placeholder_service = services_using_resource.first&.service || business.services.first
        if placeholder_service.present?
          Resources::Availability.new(business:, service: placeholder_service, starts_at: now, ends_at: now + 15.minutes).available_quantity(resource)
        else
          resource.quantity.to_i
        end
      end
    end

    def occupied_until
      items = current_appointments + current_blocks
      items.map(&:ends_at).max
    end

    def conflict_examples
      examples = []
      current = active_today_appointments.first
      if current.present?
        examples << "#{current.employee_membership&.name || 'Una profesional'} puede tener agenda libre, pero #{resource.name} está reservado de #{CustomerDateFormatter.time_label(current.starts_at)} a #{CustomerDateFormatter.time_label(current.ends_at).delete_suffix(' hs')}."
      end

      block = today_blocks.first
      if block.present?
        examples << "#{resource.name} tiene bloqueo por #{block.reason_label.downcase} de #{CustomerDateFormatter.time_label(block.starts_at)} a #{CustomerDateFormatter.time_label(block.ends_at).delete_suffix(' hs')}."
      end

      if examples.blank?
        service_name = services_using_resource.first&.service&.name || "un servicio asociado"
        examples << "Si #{service_name} requiere #{resource.name}, ese horario no se ofrece cuando el recurso no tiene capacidad libre."
      end

      examples
    end

    private
      def now
        @now ||= Time.current
      end

      def today_range
        @today_range ||= Time.zone.today.beginning_of_day..Time.zone.today.end_of_day
      end
  end
end
