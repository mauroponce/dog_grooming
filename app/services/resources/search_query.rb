module Resources
  class SearchQuery
    Metric = Struct.new(:label, :value, :hint, :tone, keyword_init: true)
    Filter = Struct.new(:key, :label, :count, :active, keyword_init: true)

    FILTERS = {
      "all" => "Todos",
      "cabin" => "Áreas de grooming",
      "machine" => "Máquinas",
      "bed" => "Caniles",
      "table" => "Mesas",
      "occupied" => "Ocupados",
      "maintenance" => "Mantenimiento"
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

    def resources
      @resources ||= begin
        relation = business.bookable_resources.visible.includes(:branch, :services)
        relation = apply_search(relation)
        relation = apply_filter(relation)
        relation.distinct.order(active: :desc, status: :asc, name: :asc).to_a
      end
    end

    def selected_resource
      @selected_resource ||= begin
        selected = business.bookable_resources.visible.includes(:branch, :services).find_by(id: params[:resource_id]) if params[:resource_id].present?
        selected || resources.first
      end
    end

    def metrics
      now = Time.current
      [
        Metric.new(label: "Recursos activos", value: business.bookable_resources.active.count, hint: "operativos", tone: :green),
        Metric.new(label: "Ocupados ahora", value: occupied_resource_ids(now).count, hint: "en turno", tone: :violet),
        Metric.new(label: "Bloqueados", value: blocked_resource_ids(now).count, hint: "mantenimiento", tone: :amber),
        Metric.new(label: "Conflictos evitados", value: prevented_conflicts_count, hint: "semana", tone: :sky)
      ]
    end

    def filters
      FILTERS.map do |key, label|
        Filter.new(key:, label:, count: count_for_filter(key), active: key == filter)
      end
    end

    private
      def apply_search(relation)
        return relation if query.blank?

        needle = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        relation.left_joins(:services, :branch).where(
          "bookable_resources.name ILIKE :needle OR bookable_resources.resource_type ILIKE :needle OR bookable_resources.status ILIKE :needle OR bookable_resources.notes ILIKE :needle OR services.name ILIKE :needle OR branches.name ILIKE :needle",
          needle:
        )
      end

      def apply_filter(relation)
        case filter
        when "cabin", "machine", "bed", "table"
          relation.where(resource_type: filter)
        when "maintenance"
          relation.where(status: "maintenance")
        when "occupied"
          relation.where(id: occupied_resource_ids(Time.current).presence || [ 0 ])
        else
          relation
        end
      end

      def count_for_filter(key)
        case key
        when "all" then business.bookable_resources.visible.count
        when "occupied" then occupied_resource_ids(Time.current).count
        when "maintenance" then business.bookable_resources.visible.where(status: "maintenance").count
        else business.bookable_resources.visible.where(resource_type: key).count
        end
      end

      def occupied_resource_ids(now)
        business.appointments.active
          .where.not(bookable_resource_id: nil)
          .where("starts_at <= ? AND ends_at > ?", now, now)
          .distinct
          .pluck(:bookable_resource_id)
      end

      def blocked_resource_ids(now)
        block_ids = business.resource_blocks.active
          .where("starts_at <= ? AND ends_at > ?", now, now)
          .distinct
          .pluck(:bookable_resource_id)
        maintenance_ids = business.bookable_resources.visible.where(status: "maintenance").pluck(:id)
        (block_ids + maintenance_ids).uniq
      end

      def prevented_conflicts_count
        week = Time.zone.today.beginning_of_week.beginning_of_day..Time.zone.today.end_of_week.end_of_day
        business.appointments.active.where.not(bookable_resource_id: nil).where(starts_at: week).count +
          business.resource_blocks.active.where(starts_at: week).count
      end
  end
end
