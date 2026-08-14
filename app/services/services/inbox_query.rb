module Services
  class InboxQuery
    Metric = Struct.new(:label, :value, :hint, :tone, keyword_init: true)
    Filter = Struct.new(:key, :label, :count, :active, keyword_init: true)
    CategoryRow = Struct.new(:name, :count, :hidden_count, keyword_init: true)
    ServiceStats = Struct.new(:reservations_count, :revenue_cents, keyword_init: true)

    FILTERS = {
      "all" => "Todos",
      "active" => "Activos",
      "paused" => "Pausados",
      "public" => "Públicos",
      "deposit" => "Con seña",
      "resource" => "Con recurso"
    }.freeze

    VALID_FILTERS = (FILTERS.keys + %w[bano corte higiene puppy hidden incomplete]).freeze

    attr_reader :business, :params

    def initialize(business:, params:)
      @business = business
      @params = params
    end

    def filter
      VALID_FILTERS.include?(params[:filter].to_s) ? params[:filter].to_s : "all"
    end

    def query
      params[:q].to_s.strip
    end

    def services_relation
      @services_relation ||= begin
        relation = business.services.includes(:service_category, :bookable_resources, :employee_memberships, :service_tags)
        relation = apply_search(relation)
        relation = apply_category_filter(relation)
        relation = apply_filter(relation)
        relation = apply_advanced_filters(relation)
        relation.order(active: :desc, sort_order: :asc, category: :asc, name: :asc)
      end
    end

    def services
      @services ||= services_relation.to_a
    end

    def selected_service
      @selected_service ||= begin
        selected = business.services.includes(:service_category, :bookable_resources, :employee_memberships, :service_tags).find_by(id: params[:service_id]) if params[:service_id].present?
        selected || services_relation.first
      end
    end

    def metrics
      active_services = business.services.active
      top = top_service_stat
      [
        Metric.new(label: "Servicios activos", value: active_services.count, hint: "publicables", tone: :green),
        Metric.new(label: "Con seña", value: active_services.select(&:deposit_required?).size, hint: "manual", tone: :violet),
        Metric.new(label: "Más reservado", value: top&.first || "Sin datos", hint: top ? "#{top.last} reservas" : "este mes", tone: :zinc),
        Metric.new(label: "Ticket promedio", value: average_ticket_label, hint: "este mes", tone: :zinc)
      ]
    end

    def filters
      FILTERS.map do |key, label|
        Filter.new(key:, label:, count: count_for_filter(key), active: key == filter)
      end
    end

    def categories
      category_rows = business.service_categories.active.includes(:services).ordered.map do |category|
        rows = category.services.to_a
        CategoryRow.new(
          name: category.name,
          count: rows.count,
          hidden_count: rows.count { |service| service.hidden? || service.archived? }
        )
      end

      fallback_rows = business.services.where(service_category_id: nil).group_by(&:category_label).map do |name, rows|
        CategoryRow.new(name:, count: rows.count, hidden_count: rows.count { |service| service.hidden? || service.archived? })
      end

      (category_rows + fallback_rows).sort_by(&:name)
    end

    def service_categories
      business.service_categories.active.includes(:services).ordered
    end

    def selected_service_category
      return if params[:service_category_id].blank?

      service_categories.find { |category| category.id.to_s == params[:service_category_id].to_s }
    end

    def selected_service_category_id
      selected_service_category&.id
    end

    def grouped_services
      services.group_by { |service| service.service_category || category_row_for(service.category_label) }
    end

    def employees
      business.employee_memberships.available_for_booking.order(:name)
    end

    def resources
      business.bookable_resources.active.order(:name)
    end

    def service_templates
      business.service_templates
    end

    def suggested_service_templates(limit: 12)
      existing_names = business.services.pluck(:name).map { |name| normalize_template_name(name) }
      service_templates.reject { |template| existing_names.include?(normalize_template_name(template[:name])) }.first(limit)
    end

    def services_without_deposit_count
      return 0 unless business.deposits_enabled?

      business.services.active.where("price_cents > 0").select { |service| !service.deposit_required? }.size
    end

    def top_service_stat
      @top_service_stat ||= month_appointments.joins(:service).group("services.name").count.max_by { |_name, count| count }
    end

    def average_ticket_cents
      @average_ticket_cents ||= begin
        relation = active_month_appointments.where("final_price_cents > 0")
        count = relation.count
        count.positive? ? relation.sum(:final_price_cents) / count : 0
      end
    end

    def average_ticket_label
      "$#{(average_ticket_cents.to_i / 100).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
    end

    def monthly_stats_for(service_rows)
      ids = Array(service_rows).map(&:id)
      return {} if ids.blank?

      scoped = month_appointments.where(service_id: ids)
      counts = scoped.group(:service_id).count
      revenue = scoped.where.not(status: Appointment.statuses.values_at(*Appointment::TERMINAL_STATUSES)).group(:service_id).sum(:final_price_cents)

      ids.index_with do |service_id|
        ServiceStats.new(
          reservations_count: counts.fetch(service_id, 0),
          revenue_cents: revenue.fetch(service_id, 0)
        )
      end
    end

    def team_plan?
      business.team_features_available?
    end

    def to_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << [ "Nombre", "Categoría", "Duración", "Precio", "Visibilidad", "Seña", "Profesionales", "Recursos", "Tags" ]
        services.each do |service|
          csv << [
            service.name,
            service.category_label,
            service.duration_minutes,
            service.display_price,
            service.visibility_label,
            service.deposit_summary,
            service.employee_memberships.map(&:name).join(", "),
            service.bookable_resources.map(&:name).join(", "),
            service.tags_text
          ]
        end
      end
    end

    private
      def apply_search(relation)
        return relation if query.blank?

        needle = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        relation.where("services.name ILIKE :needle", needle:)
      end

      def apply_category_filter(relation)
        return relation if selected_service_category.blank?

        relation.where(service_category_id: selected_service_category.id)
      end

      def apply_filter(relation)
        case filter
        when "active"
          relation.where(active: true, archived_at: nil)
        when "paused"
          relation.where("services.active = ? OR services.archived_at IS NOT NULL", false)
        when "public"
          relation.where(id: business.services.publicly_bookable.select(:id))
        when "bano"
          relation.where("category ILIKE :bano OR name ILIKE :bano", bano: "%Baño%")
        when "corte"
          relation.where("category ILIKE :corte OR name ILIKE :corte", corte: "%Corte%")
        when "higiene"
          relation.where("category ILIKE :higiene OR name ILIKE :higiene", higiene: "%Higiene%")
        when "puppy"
          relation.where("category ILIKE :puppy OR name ILIKE :puppy OR name ILIKE :cachorro", puppy: "%Puppy%", cachorro: "%cachorro%")
        when "deposit"
          with_deposit(relation)
        when "resource"
          relation.joins(:bookable_resources).distinct
        when "hidden"
          relation.where("active = false OR visibility_mode = ?", "hidden")
        when "incomplete"
          ids = business.services.select(&:incomplete?).map(&:id)
          relation.where(id: ids.presence || [ 0 ])
        else
          relation
        end
      end

      def apply_advanced_filters(relation)
        relation = relation.where(visibility_mode: params[:visibility_mode]) if Service::VISIBILITY_MODES.include?(params[:visibility_mode].to_s)
        relation = with_deposit(relation) if params[:deposit].to_s == "yes"
        relation = without_deposit(relation) if params[:deposit].to_s == "no"
        relation = relation.joins(:employee_memberships).where(employee_memberships: { id: params[:employee_membership_id] }) if params[:employee_membership_id].present?
        relation = relation.joins(:bookable_resources).where(bookable_resources: { id: params[:bookable_resource_id] }) if params[:bookable_resource_id].present?
        relation = relation.where(duration_minutes: params[:duration_minutes]) if params[:duration_minutes].present?
        relation = relation.where("price_cents >= ?", price_param(:min_price) * 100) if price_param(:min_price)
        relation = relation.where("price_cents <= ?", price_param(:max_price) * 100) if price_param(:max_price)
        relation
      end

      def price_param(key)
        value = params[key].to_s.strip
        return if value.blank?

        Integer(value, exception: false)
      end

      def with_deposit(relation)
        return relation.none unless business.deposits_enabled?

        relation.where(deposit_required: true).where("deposit_amount_cents > 0")
      end

      def without_deposit(relation)
        return relation unless business.deposits_enabled?

        relation.where("deposit_required = ? OR deposit_amount_cents = 0", false)
      end

      def normalize_template_name(name)
        I18n.transliterate(name.to_s).downcase.gsub(/[^a-z0-9]+/, " ").squish
      end

      def category_row_for(name)
        CategoryRow.new(name:, count: 0, hidden_count: 0)
      end

      def count_for_filter(key)
        case key
        when "all" then business.services.count
        when "active" then business.services.active.count
        when "paused" then business.services.where("services.active = ? OR services.archived_at IS NOT NULL", false).count
        when "public" then business.services.publicly_bookable.count
        when "resource" then business.services.joins(:bookable_resources).distinct.count
        else
          scoped = self.class.new(business:, params: ActionController::Parameters.new(filter: key)).services
          scoped.count
        end
      end

      def month_range
        Time.zone.today.beginning_of_month.beginning_of_day..Time.zone.today.end_of_month.end_of_day
      end

      def month_appointments
        business.appointments.where(starts_at: month_range)
      end

      def active_month_appointments
        month_appointments.where.not(status: Appointment.statuses.values_at(*Appointment::TERMINAL_STATUSES))
      end
  end
end
