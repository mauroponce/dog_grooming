module Team
  class ProfessionalsQuery
    Metric = Struct.new(:label, :value, :hint, :tone, keyword_init: true)
    Filter = Struct.new(:key, :label, :count, :active, keyword_init: true)
    Role = Struct.new(:name, :description, :count, :tone, keyword_init: true)

    FILTERS = {
      "all" => "Todos",
      "active" => "Activos",
      "invited" => "Invitados",
      "coordination" => "Recepción",
      "employees" => "Profesionales",
      "admins" => "Admins"
    }.freeze

    attr_reader :business, :params

    def initialize(business:, params:)
      @business = business
      @params = params
    end

    def query
      params[:q].to_s.strip
    end

    def filter
      FILTERS.key?(params[:filter].to_s) ? params[:filter].to_s : "all"
    end

    def employees
      @employees ||= begin
        relation = business.employee_memberships.with_attached_profile_photo.includes(:branch, :services, :employee_availability_rules, user: { profile_photo_attachment: :blob })
        relation = apply_search(relation)
        relation = apply_filter(relation)
        relation = apply_advanced_filters(relation)
        relation.ordered.to_a
      end
    end

    def selected_employee
      @selected_employee ||= begin
        selected = business.employee_memberships.with_attached_profile_photo.includes(:branch, :services, :employee_availability_rules, user: { profile_photo_attachment: :blob }).find_by(id: params[:employee_id]) if params[:employee_id].present?
        selected || employees.first
      end
    end

    def metrics
      reservable_count = business.employee_memberships.available_for_booking.count
      pending_count = business.employee_memberships.pending.count
      assigned_count = business.appointments.active.where(starts_at: week_range).where.not(employee_membership_id: nil).count
      billing = business.billing_amount
      [
        Metric.new(label: "Profesionales con agenda", value: billing.active_professionals_count, hint: "sin adicional", tone: :green),
        Metric.new(label: "Turnos asignados", value: assigned_count, hint: "semana", tone: :violet),
        Metric.new(label: "Invitaciones", value: pending_count, hint: "pendientes", tone: :amber),
        Metric.new(label: "Carga promedio", value: "#{average_load}%", hint: "agenda", tone: :sky)
      ]
    end

    def filters
      FILTERS.map do |key, label|
        Filter.new(key:, label:, count: count_for_filter(key), active: key == filter)
      end
    end

    def roles
      [
        Role.new(name: "Admin", description: "La cuenta dueña administra negocio, facturación y permisos sensibles.", count: employees.count(&:owner_profile?), tone: :violet),
        Role.new(name: "Recepción", description: "Puede ver la agenda completa y operar turnos según permisos asignados.", count: employees.count { |employee| employee.role_label == "Recepción" }, tone: :sky),
        Role.new(name: "Profesional", description: "Gestiona sus turnos y clientes según permisos asignados.", count: employees.count { |employee| employee.role_label == "Profesional" && !employee.pending? }, tone: :zinc),
        Role.new(name: "Invitado", description: "Recibió invitación, pero todavía no aceptó el acceso.", count: employees.count(&:pending?), tone: :amber)
      ]
    end

    def pending_invitations
      business.employee_memberships.pending.includes(:services).order(invitation_sent_at: :desc, created_at: :desc)
    end

    def services
      business.services.active.order(:category, :sort_order, :name)
    end

    def branches
      business.branches.active.order(:name)
    end

    def week_range
      Time.zone.today.beginning_of_week.beginning_of_day..Time.zone.today.end_of_week.end_of_day
    end

    private
      def apply_search(relation)
        return relation if query.blank?

        needle = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        service_ids = Service.joins(:employee_memberships)
          .where(employee_memberships: { business_id: business.id })
          .where("services.name ILIKE :needle OR services.category ILIKE :needle", needle: needle)
          .pluck("employee_memberships.id")
        relation.where(
          "employee_memberships.name ILIKE :needle OR employee_memberships.email_address ILIKE :needle OR employee_memberships.specialty ILIKE :needle OR employee_memberships.id IN (:ids)",
          needle: needle,
          ids: service_ids.presence || [ 0 ]
        )
      end

      def apply_filter(relation)
        case filter
        when "active"
          relation.active.where(archived_at: nil)
        when "coordination"
          relation.active.where(archived_at: nil, can_receive_appointments: false)
        when "employees"
          relation.active.where(archived_at: nil, can_receive_appointments: true)
        when "invited"
          relation.pending
        when "admins"
          relation.active.where(archived_at: nil).where(user_id: business.owner_id)
        else
          relation
        end
      end

      def without_owner(relation)
        relation.where("employee_memberships.user_id IS NULL OR employee_memberships.user_id != ?", business.owner_id)
      end

      def apply_advanced_filters(relation)
        relation = relation.where(status: params[:status]) if EmployeeMembership::STATUSES.include?(params[:status].to_s)
        relation = relation.where("specialty ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:specialty].to_s)}%") if params[:specialty].present?
        relation = relation.joins(:services).where(services: { id: params[:service_id] }) if params[:service_id].present?
        relation = relation.where("permissions ? 'can_approve_deposits' OR permissions ? 'can_reject_deposits' OR permissions ? 'deposits_review'") if params[:deposit_permission].to_s == "yes"
        relation
      end

      def average_load
        rows = business.employee_memberships.available_for_booking.includes(:employee_availability_rules).to_a
        return 0 if rows.blank?

        values = rows.map { |employee| ProfessionalProfilePresenter.new(employee: employee, business: business).weekly_occupancy }
        (values.sum / values.size.to_f).round
      end

      def count_for_filter(key)
        return business.employee_memberships.count if key == "all"

        self.class.new(business:, params: ActionController::Parameters.new(filter: key)).employees.count
      end
  end
end
