module Team
  class ProfessionalProfilePresenter
    DayLoad = Struct.new(:weekday, :label, :active, :range_label, :booked_minutes, :capacity_minutes, :occupancy, keyword_init: true)
    Stat = Struct.new(:label, :value, :hint, :tone, keyword_init: true)

    attr_reader :employee, :business

    def initialize(employee:, business:)
      @employee = employee
      @business = business
    end

    def today_count
      appointments_today.count
    end

    def week_count
      appointments_week.count
    end

    def weekly_occupancy
      capacity = weekly_load.sum(&:capacity_minutes)
      return 0 if capacity.zero?

      ((weekly_load.sum(&:booked_minutes) / capacity.to_f) * 100).round
    end

    def day_status
      return Stat.new(label: "Inactivo", value: "Inactivo", hint: "oculto", tone: :zinc) if employee.archived?

      today = daily_load_for(Time.zone.today.wday)
      return Stat.new(label: "Estado", value: "Sin horario hoy", hint: "agenda", tone: :amber) unless today&.active
      return Stat.new(label: "Estado", value: "Agenda completa", hint: "hoy", tone: :rose) if today.occupancy >= 100

      Stat.new(label: "Estado", value: "Disponible hoy", hint: "hoy", tone: :green)
    end

    def stats
      [
        Stat.new(label: "Turnos hoy", value: today_count, hint: "asignados", tone: :violet),
        Stat.new(label: "Semana", value: week_count, hint: "turnos", tone: :zinc),
        Stat.new(label: "Ocupación", value: "#{weekly_occupancy}%", hint: "semanal", tone: :sky),
        day_status
      ]
    end

    def weekly_load
      @weekly_load ||= Business::DAYS.map { |weekday, _name| daily_load_for(weekday) }
    end

    def services
      @services ||= business.services.active.includes(:employee_memberships).order(:category, :sort_order, :name).select do |service|
        service.employee_membership_ids.blank? || service.employee_membership_ids.include?(employee.id)
      end
    end

    def explicit_services
      employee.services.active.order(:category, :sort_order, :name)
    end

    def permissions
      [
        [ "can_view_all_bookings", "Ver agenda completa", "Puede ver todos los turnos del centro." ],
        [ "can_cancel_bookings", "Cancelar turnos", "Puede cancelar turnos desde el panel." ],
        [ "can_approve_deposits", "Aprobar comprobantes", "Puede aprobar señas de sus turnos." ],
        [ "can_reject_deposits", "Rechazar comprobantes", "Puede rechazar comprobantes de sus turnos." ],
        [ "can_view_all_customers", "Ver todas las clientes", "Puede acceder al listado completo de clientes." ],
        [ "can_edit_customers", "Editar clientes", "Puede editar datos básicos de clientes." ],
        [ "can_manage_services", "Editar servicios", "Puede cambiar precio, duración y seña." ],
        [ "can_manage_availability", "Gestionar disponibilidad", "Puede editar disponibilidad." ],
        [ "can_manage_resources", "Gestionar recursos", "Puede editar bañeras, mesas, equipos o caniles." ]
      ]
    end

    def whatsapp_message
      "Hola #{employee.name}, te escribo de #{business.name} por tu agenda de turnos."
    end

    def suggestion
      lowest = weekly_load.select(&:active).min_by(&:occupancy)
      return "Este profesional no tiene horarios activos esta semana. Revisá su disponibilidad base." if lowest.blank?
      return "#{employee.name} tiene alta ocupación toda la semana. Podés derivar turnos a otra agenda disponible." if weekly_occupancy >= 85

      "#{employee.name} tiene baja ocupación el #{lowest.label.downcase}. Podés ofrecer turnos cortos de #{employee.specialty_label.downcase}."
    end

    def schedule_rules
      employee.ensure_availability_rules!
      employee.employee_availability_rules.ordered
    end

    private
      def appointments_today
        @appointments_today ||= appointment_scope.where(starts_at: Time.zone.today.all_day)
      end

      def appointments_week
        @appointments_week ||= appointment_scope.where(starts_at: Time.zone.today.beginning_of_week.beginning_of_day..Time.zone.today.end_of_week.end_of_day)
      end

      def appointment_scope
        business.appointments.active.where(employee_membership: employee)
      end

      def daily_load_for(weekday)
        rule = schedule_rules.find { |item| item.weekday == weekday }
        booked_minutes = appointments_week.select { |appointment| appointment.starts_at.wday == weekday }.sum do |appointment|
          ((appointment.ends_at - appointment.starts_at) / 60).to_i
        end
        capacity = rule&.active? ? (((time_seconds(rule.end_time) - time_seconds(rule.start_time)) / 60).to_i) : 0
        occupancy = capacity.positive? ? [ ((booked_minutes / capacity.to_f) * 100).round, 100 ].min : 0

        DayLoad.new(
          weekday: weekday,
          label: Business::DAYS.to_h.fetch(weekday).first(3),
          active: rule&.active? || false,
          range_label: rule&.active? ? "#{rule.start_time.strftime('%H:%M')} - #{rule.end_time.strftime('%H:%M')}" : "No atiende",
          booked_minutes: booked_minutes,
          capacity_minutes: capacity,
          occupancy: occupancy
        )
      end

      def time_seconds(value)
        return 0 if value.blank?

        value.seconds_since_midnight
      end
  end
end
