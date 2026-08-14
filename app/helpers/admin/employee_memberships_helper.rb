module Admin
  module EmployeeMembershipsHelper
    def team_metric_hint_classes(tone)
      {
        green: "bg-emerald-50 text-emerald-700",
        violet: "bg-brand-50 text-brand-700",
        amber: "bg-amber-50 text-amber-700",
        sky: "bg-sky-50 text-sky-700",
        rose: "bg-rose-50 text-rose-700",
        zinc: "bg-zinc-100 text-zinc-600"
      }.fetch(tone, "bg-zinc-100 text-zinc-600")
    end

    def team_metric_hint_text_classes(tone)
      {
        green: "text-emerald-600",
        violet: "text-brand-700",
        amber: "text-amber-600",
        sky: "text-sky-600",
        rose: "text-rose-600",
        zinc: "text-zinc-500"
      }.fetch(tone, "text-zinc-500")
    end

    def team_status_classes(employee)
      return "bg-amber-50 text-amber-700" if employee.pending?
      return "bg-zinc-100 text-zinc-600" if employee.archived?

      "bg-emerald-50 text-emerald-700"
    end

    def team_status_label(employee)
      return "Invitación pendiente" if employee.pending?
      return "Inactivo" if employee.archived?

      "Activo"
    end

    def team_access_level_options
      EmployeeMembership::ACCESS_LEVELS.map do |key, config|
        [ config.fetch(:label), key, { "data-description": config.fetch(:description) } ]
      end
    end

    def team_access_level_label(employee)
      employee.access_level_label
    end

    def team_access_level_description(employee)
      employee.access_level_description
    end

    def team_trial_banner_text(business)
      return unless business.trial_active? && !business.subscription_active?

      days = [ (business.trial_ends_at.to_date - Time.zone.today).to_i, 0 ].max
      "Activá tu suscripción para mantener el acceso cuando finalice el período de prueba gratuito, dentro de #{days} #{days == 1 ? 'día' : 'días'}"
    end

    def team_dark_avatar_classes(employee)
      return "border-brand-500 bg-brand-700 text-white" if employee.owner_profile?
      return "border-rose-400 bg-rose-950 text-rose-300" if employee.pending?
      return "border-zinc-500 bg-zinc-900 text-zinc-300" if employee.archived? || employee.access_level == "none"

      "border-cyan-400 bg-cyan-950 text-cyan-200"
    end

    def team_member_calendar_path(employee)
      admin_calendar_path(employee_id: employee.id)
    end

    def team_member_appointments_path(employee)
      admin_calendar_path(q: employee.name)
    end

    def team_role_classes(employee)
      return "bg-ink text-white" if employee.owner_profile?
      return "bg-sky-50 text-sky-700" if employee.can?("can_view_all_bookings")

      "bg-brand-50 text-brand-700"
    end

    def team_role_description(employee)
      return "Acceso completo." if employee.owner_profile?
      return "No recibe turnos." if employee.can?("can_view_all_bookings")
      return "No recibe turnos ahora." if employee.archived?

      "Recibe turnos."
    end

    def team_permission_badges(employee)
      if employee.owner_profile?
        [
          { label: "todo", tone: :ink },
          { label: "configuración", tone: :violet },
          { label: "facturación", tone: :amber }
        ]
      elsif employee.can?("can_view_all_bookings")
        [
          { label: "turnos", tone: :zinc },
          { label: "clientes", tone: :zinc },
          { label: "comprobantes", tone: :amber },
          { label: "sin ventas", tone: :rose }
        ]
      else
        [
          { label: "mis turnos", tone: :zinc },
          { label: "historial", tone: :zinc },
          { label: "notas/fotos", tone: :zinc },
          { label: "sin caja", tone: :rose }
        ]
      end
    end

    def team_permission_badge_classes(tone)
      {
        ink: "bg-ink text-white",
        violet: "bg-brand-50 text-brand-700",
        amber: "bg-amber-50 text-amber-700",
        rose: "bg-rose-50 text-rose-700",
        zinc: "bg-zinc-100 text-zinc-600"
      }.fetch(tone, "bg-zinc-100 text-zinc-600")
    end

    def team_employee_summary_metrics(query)
      employees = query.business.employee_memberships.includes(:services).to_a
      active = employees.select { |employee| employee.active? && !employee.archived? }
      active_staff = active.reject(&:owner_profile?)
      reception_count = active_staff.count { |employee| employee.can?("can_view_all_bookings") }
      professional_count = active_staff.count { |employee| !employee.can?("can_view_all_bookings") }
      pending_count = employees.count(&:pending?)

      [
        { label: "Usuarios activos", value: active.count, hint: "pueden iniciar sesión", tone: :green },
        { label: "Profesionales", value: professional_count, hint: "reciben turnos", tone: :zinc },
        { label: "Recepción", value: reception_count, hint: "opera la agenda", tone: :zinc },
        { label: "Invitaciones", value: pending_count, hint: pending_count == 1 ? "pendiente" : "pendientes", tone: :amber }
      ]
    end

    def team_activity_title(employee)
      return "Ahora" if employee.user_id.present? && employee.user_id == current_user&.id
      return "Enviada #{format_ar_date(employee.invitation_sent_at)}" if employee.pending? && employee.invitation_sent_at.present?
      return format_ar_datetime(employee.last_access_at) if employee.last_access_at.present?
      return format_ar_date(employee.archived_at) if employee.archived? && employee.archived_at.present?

      "Sin ingresos"
    end

    def team_activity_detail(employee)
      return "Sesión actual." if employee.user_id.present? && employee.user_id == current_user&.id
      return "Todavía no aceptó." if employee.pending?
      return "Desactivado por admin." if employee.archived?
      return "Último ingreso registrado." if employee.last_access_at.present?

      "Sin actividad registrada."
    end

    def team_employee_row_classes(employee)
      base = "transition hover:bg-zinc-50/70"
      return "#{base} opacity-75" if employee.archived?

      base
    end

    def team_mobile_access_text(employee)
      if employee.owner_profile?
        "Acceso completo a configuración, agenda, clientes, ventas y facturación."
      elsif employee.can?("can_view_all_bookings")
        "Ve toda la agenda, clientes y comprobantes. No ve ventas ni facturación."
      else
        "Ve su agenda, historial necesario, notas y fotos internas. No ve caja ni ventas."
      end
    end

    def team_receives_bookings?(employee)
      employee.active? && !employee.archived? && !employee.owner_profile? && !employee.can?("can_view_all_bookings")
    end

    def team_profile_summary(employee)
      return "Cuenta administradora. Tiene acceso completo al negocio, facturación, permisos y configuración." if employee.owner_profile?
      return "Usuario de recepción. Opera agenda, turnos, clientes y comprobantes sin acceder a ventas ni facturación." if employee.can?("can_view_all_bookings")
      return "Profesional del centro. Puede operar su agenda, sus turnos y el historial necesario para atender clientes." if team_receives_bookings?(employee)

      "Empleado inactivo o sin agenda pública. Conserva historial, pero no opera turnos mientras esté desactivado."
    end

    def team_agenda_visibility_label(employee)
      employee.owner_profile? || employee.can?("can_view_all_bookings") ? "Toda la agenda" : "Su agenda"
    end

    def team_agenda_visibility_hint(employee)
      employee.owner_profile? || employee.can?("can_view_all_bookings") ? "Todos los profesionales." : "Solo sus turnos."
    end

    def team_receives_bookings_label(employee)
      team_receives_bookings?(employee) ? "Sí" : "No"
    end

    def team_receives_bookings_hint(employee)
      return "Aparece como profesional." if team_receives_bookings?(employee)

      "Solo usa el sistema."
    end

    def team_menu_visibility(employee)
      [
        { label: "Inicio", status: :visible },
        { label: "Turnos", status: employee.owner_profile? || employee.can?("can_view_all_bookings") || employee.can?("can_create_bookings") || employee.can?("can_edit_bookings") ? :visible : :hidden },
        { label: "Clientes", status: employee.owner_profile? || employee.can?("can_view_all_customers") || employee.can?("can_view_customer_history") || employee.can?("can_edit_customers") ? :visible : :hidden },
        { label: "Servicios", status: employee.owner_profile? || employee.can?("can_manage_services") ? :visible : :hidden },
        { label: "Comprobantes", status: employee.owner_profile? || employee.can?("can_approve_deposits") || employee.can?("can_reject_deposits") ? :visible : :hidden }
      ]
    end

    def team_hidden_modules(employee)
      modules = []
      modules << "Ventas" unless employee.owner_profile? || employee.can?("can_view_sales_dashboard")
      modules << "Caja estimada" unless employee.owner_profile? || employee.can?("can_view_sales_dashboard")
      modules << "Facturación" unless employee.owner_profile?
      modules << "Equipo y permisos" unless employee.owner_profile?
      modules << "Configuración avanzada" unless employee.owner_profile? || employee.can?("can_manage_services") || employee.can?("can_manage_availability") || employee.can?("can_manage_resources") || employee.can?("can_manage_public_presence")
      modules
    end

    def team_menu_status_label(status)
      { visible: "visible", partial: "parcial", hidden: "oculto" }.fetch(status, "oculto")
    end

    def team_menu_status_classes(status)
      {
        visible: "text-emerald-700",
        partial: "text-amber-700",
        hidden: "text-rose-700"
      }.fetch(status, "text-zinc-500")
    end

    def team_permission_rows(employee)
      [
        {
          module: "Agenda y turnos",
          status: team_permission_status(employee, %w[can_view_all_bookings can_create_bookings can_edit_bookings can_cancel_bookings]),
          description: team_appointments_permission_description(employee)
        },
        {
          module: "Clientes",
          status: team_permission_status(employee, %w[can_view_all_customers can_view_customer_history can_edit_customers]),
          description: team_customers_permission_description(employee)
        },
        {
          module: "Comprobantes",
          status: team_permission_status(employee, %w[can_approve_deposits can_reject_deposits]),
          description: team_deposits_permission_description(employee)
        },
        {
          module: "Servicios y horarios",
          status: team_permission_status(employee, %w[can_manage_services can_manage_availability can_manage_resources]),
          description: team_setup_permission_description(employee)
        },
        {
          module: "Ventas y caja",
          status: employee.owner_profile? || employee.can?("can_view_sales_dashboard") ? :allowed : :blocked,
          description: employee.owner_profile? || employee.can?("can_view_sales_dashboard") ? "Puede ver reportes comerciales." : "No ve ventas posibles, caja estimada, reportes ni ganancias."
        },
        {
          module: "Configuración",
          status: employee.owner_profile? ? :allowed : :blocked,
          description: employee.owner_profile? ? "Puede editar negocio, equipo, permisos y facturación." : "No puede editar negocio, equipo, permisos ni facturación."
        }
      ]
    end

    def team_permission_status(employee, permissions)
      return :allowed if employee.owner_profile?

      matched = permissions.count { |permission| employee.can?(permission) }
      return :blocked if matched.zero?
      return :allowed if matched == permissions.size

      :partial
    end

    def team_permission_status_label(status)
      { allowed: "Permitido", partial: "Parcial", blocked: "Bloqueado" }.fetch(status, "Bloqueado")
    end

    def team_permission_status_classes(status)
      {
        allowed: "bg-emerald-50 text-emerald-700",
        partial: "bg-amber-50 text-amber-700",
        blocked: "bg-rose-50 text-rose-700"
      }.fetch(status, "bg-zinc-100 text-zinc-600")
    end

    def team_appointments_permission_description(employee)
      return "Puede ver toda la agenda, crear turnos, reprogramar y cancelar." if employee.owner_profile? || employee.can?("can_view_all_bookings")
      return "Puede crear o editar turnos según permisos asignados." if employee.can?("can_create_bookings") || employee.can?("can_edit_bookings")

      "No tiene acceso operativo a turnos."
    end

    def team_customers_permission_description(employee)
      return "Puede ver y editar clientes de todo el centro." if employee.owner_profile? || employee.can?("can_view_all_customers")
      return "Puede ver historial de clientas asignadas." if employee.can?("can_view_customer_history")
      return "Puede editar datos básicos de clientes." if employee.can?("can_edit_customers")

      "No tiene acceso al listado de clientes."
    end

    def team_deposits_permission_description(employee)
      return "Puede aprobar y rechazar comprobantes." if employee.owner_profile? || (employee.can?("can_approve_deposits") && employee.can?("can_reject_deposits"))
      return "Puede revisar comprobantes con permisos parciales." if employee.can?("can_approve_deposits") || employee.can?("can_reject_deposits")

      "No puede aprobar ni rechazar comprobantes."
    end

    def team_setup_permission_description(employee)
      return "Puede administrar servicios, disponibilidad y recursos." if employee.owner_profile?

      enabled = []
      enabled << "servicios" if employee.can?("can_manage_services")
      enabled << "disponibilidad" if employee.can?("can_manage_availability")
      enabled << "recursos" if employee.can?("can_manage_resources")
      return "Puede editar #{enabled.to_sentence}." if enabled.any?

      "No puede editar servicios, horarios ni recursos."
    end

    def team_card_classes(employee, selected)
      base = "rounded-lg border bg-white p-4 transition"
      return "#{base} border-brand-300 bg-brand-50/70 shadow-sm" if selected
      return "#{base} border-amber-200 bg-amber-50/60" if employee.pending?
      return "#{base} border-zinc-200 bg-zinc-50 opacity-80" if employee.archived?

      "#{base} border-zinc-200 hover:border-brand-200 hover:bg-brand-50/25"
    end

    def team_avatar_classes(employee, selected = false)
      return "bg-brand-600 text-white" if selected
      return "bg-amber-50 text-amber-700" if employee.pending?
      return "bg-zinc-100 text-zinc-500" if employee.archived?

      "bg-emerald-50 text-emerald-700"
    end

    def team_permission_checked?(employee, key)
      employee.permission_keys.include?(key)
    end

    def team_money(cents)
      number_to_currency(cents.to_i / 100, unit: "$", precision: 0, delimiter: ".")
    end

    def team_last_access_label(employee)
      employee.last_access_at.present? ? format_ar_datetime(employee.last_access_at) : "Sin ingresos"
    end

    def team_invitation_label(employee)
      return "Aceptada" if employee.invitation_accepted_at.present?
      return "No enviada" if employee.invitation_sent_at.blank?

      "Enviada #{format_ar_datetime(employee.invitation_sent_at)}"
    end
  end
end
