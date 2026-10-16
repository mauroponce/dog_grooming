module Customers
  class InboxQuery
    Metric = Struct.new(:label, :value, :hint, :tone, keyword_init: true)
    Filter = Struct.new(:key, :label, :count, :active, keyword_init: true)
    Segment = Struct.new(:key, :title, :body, :tone, :url, keyword_init: true)

    FILTERS = {
      "all" => "Todos",
      "frequent" => "Frecuentes",
      "pending_deposit" => "Con seña pendiente",
      "new" => "Nuevos",
      "no_show" => "No-show previo"
    }.freeze

    SORT_OPTIONS = {
      "created_at_desc" => "Más nuevos",
      "created_at_asc" => "Más antiguos",
      "completed_appointments_desc" => "Más turnos",
      "completed_appointments_asc" => "Menos turnos"
    }.freeze

    attr_reader :business, :customers_scope, :appointments_scope, :params, :current_user

    def initialize(business:, customers_scope:, appointments_scope:, params:, current_user:)
      @business = business
      @customers_scope = customers_scope
      @appointments_scope = appointments_scope
      @params = params
      @current_user = current_user
    end

    def filter
      FILTERS.key?(params[:filter].to_s) ? params[:filter].to_s : "all"
    end

    def query
      params[:q].to_s.strip
    end

    def customers
      @customers ||= customers_relation.to_a
    end

    def customers_relation
      @customers_relation ||= begin
        relation = customers_scope
        relation = apply_search(relation)
        relation = apply_filter(relation)
        relation = apply_advanced_filters(relation)
        relation = relation.joins(appointment_count_join) if appointment_count_sort?
        relation.order(Arel.sql(sort_order))
      end
    end

    def sort
      SORT_OPTIONS.key?(params[:sort].to_s) ? params[:sort].to_s : "created_at_desc"
    end

    def selected_customer
      @selected_customer ||= begin
        selected = customers_scope.find_by(id: params[:customer_id]) if params[:customer_id].present?
        selected || customers.first
      end
    end

    def metrics
      [
        Metric.new(label: "Registrados", value: customers_scope.count, hint: "#{new_this_month_count} este mes", tone: :violet),
        Metric.new(label: "Con próximo turno", value: upcoming_customer_ids.size, hint: "activos", tone: :green),
        Metric.new(label: "Con deuda/seña", value: pending_deposit_customer_ids.size, hint: "revisar", tone: :rose)
      ]
    end

    def filters
      FILTERS.map do |key, label|
        Filter.new(key:, label:, count: count_for_filter(key), active: key == filter)
      end
    end

    def segments
      [
        Segment.new(
          key: "frequent",
          title: "Frecuentes de grooming",
          body: "#{frequent_grooming_customer_ids.size} tutores vuelven por servicios de grooming.",
          tone: :violet,
          url: Rails.application.routes.url_helpers.admin_customer_profiles_path(filter: :frequent, q: "baño")
        ),
        Segment.new(
          key: "gaps",
          title: "Candidatos para huecos",
          body: "#{gap_candidate_ids.size} tutores con servicios cortos o pendientes.",
          tone: :sky,
          url: Rails.application.routes.url_helpers.admin_customer_profiles_path(filter: :upcoming)
        ),
        Segment.new(
          key: "pending_deposit",
          title: "Con seña pendiente",
          body: "#{pending_deposit_customer_ids.size} tutores necesitan seguimiento de seña.",
          tone: :rose,
          url: Rails.application.routes.url_helpers.admin_customer_profiles_path(filter: :pending_deposit)
        )
      ]
    end

    def team_plan?
      business.team_features_available?
    end

    def services
      business.services.active.order(:name)
    end

    def employees
      return EmployeeMembership.none unless team_plan?

      business.employee_memberships.active.order(:name)
    end

    def assignees
      User.where(id: [ business.owner_id ] + business.employee_memberships.active.where.not(user_id: nil).pluck(:user_id)).order(:email_address)
    end

    def to_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << [ "Nombre", "Teléfono", "Email", "Turnos", "Próximo turno", "Última visita" ]
        customers.each do |customer|
          presenter = Customers::ProfilePresenter.new(customer:, business:, appointments_scope:, current_user:)
          csv << [
            presenter.name,
            customer.phone,
            customer.email,
            presenter.total_appointments,
            presenter.next_appointment_label,
            presenter.last_visit_label
          ]
        end
      end
    end

    def upcoming_customer_ids
      @upcoming_customer_ids ||= appointments_scope.active.where("starts_at >= ?", Time.current).where.not(customer_profile_id: nil).distinct.pluck(:customer_profile_id)
    end

    def pending_deposit_customer_ids
      @pending_deposit_customer_ids ||= appointments_scope
        .where(status: Appointment.statuses.values_at("pending_deposit", "pending_deposit_review", "deposit_rejected"))
        .where.not(customer_profile_id: nil)
        .distinct
        .pluck(:customer_profile_id)
    end

    def frequent_customer_ids
      @frequent_customer_ids ||= appointments_scope
        .where.not(customer_profile_id: nil)
        .group(:customer_profile_id)
        .having("COUNT(*) >= 3")
        .count
        .keys
    end

    def no_show_customer_ids
      @no_show_customer_ids ||= customers_scope.where("no_show_count > 0 OR total_cancellations_count > 0 OR consecutive_late_cancellations_count > 0").pluck(:id)
    end

    def new_customer_ids
      @new_customer_ids ||= customers_scope.where("customer_profiles.created_at >= ?", 45.days.ago).pluck(:id)
    end

    private
      def apply_search(relation)
        return relation if query.blank?

        needle = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        phone_digits = query.gsub(/\D/, "")
        binds = { needle: needle }
        direct_conditions = [
          "customer_profiles.name ILIKE :needle",
          "customer_profiles.phone ILIKE :needle",
          "customer_profiles.normalized_phone ILIKE :needle",
          "customer_profiles.email ILIKE :needle",
          "customer_profiles.internal_notes ILIKE :needle"
        ]
        if phone_digits.present?
          binds[:phone_needle] = "%#{ActiveRecord::Base.sanitize_sql_like(phone_digits)}%"
          direct_conditions << "regexp_replace(COALESCE(customer_profiles.phone, ''), '[^0-9]', '', 'g') LIKE :phone_needle"
          direct_conditions << "regexp_replace(COALESCE(customer_profiles.normalized_phone, ''), '[^0-9]', '', 'g') LIKE :phone_needle"
        end

        appointment_customer_ids = appointments_scope
          .joins(:service)
          .where.not(customer_profile_id: nil)
          .where("services.name ILIKE :needle OR appointments.notes ILIKE :needle", needle:)
          .select(:customer_profile_id)
        note_customer_ids = ClientNote
          .where(business: business)
          .where("client_notes.title ILIKE :needle OR client_notes.body ILIKE :needle", needle:)
          .select(:customer_profile_id)

        relation.where(
          "(#{direct_conditions.join(" OR ")}) OR customer_profiles.id IN (:appointment_customer_ids) OR customer_profiles.id IN (:note_customer_ids)",
          binds.merge(appointment_customer_ids:, note_customer_ids:)
        )
      end

      def apply_filter(relation)
        ids = case filter
        when "upcoming" then upcoming_customer_ids
        when "frequent" then frequent_customer_ids
        when "pending_deposit" then pending_deposit_customer_ids
        when "new" then new_customer_ids
        when "no_show" then no_show_customer_ids
        else nil
        end
        ids ? relation.where(id: ids) : relation
      end

      def apply_advanced_filters(relation)
        relation = apply_last_visit_filter(relation)
        relation = apply_appointment_filter(relation, :service_id)
        relation = apply_appointment_filter(relation, :employee_membership_id)
        relation
      end

      def apply_last_visit_filter(relation)
        return relation if params[:last_visit_from].blank?

        from = Date.parse(params[:last_visit_from].to_s).beginning_of_day
        ids = appointments_scope
          .where("starts_at >= ?", from)
          .where.not(customer_profile_id: nil)
          .distinct
          .pluck(:customer_profile_id)
        relation.where(id: ids)
      rescue ArgumentError
        relation
      end

      def apply_appointment_filter(relation, key)
        return relation if params[key].blank?

        ids = appointments_scope
          .where(key => params[key])
          .where.not(customer_profile_id: nil)
          .distinct
          .pluck(:customer_profile_id)
        relation.where(id: ids)
      end

      def count_for_filter(key)
        case key
        when "upcoming" then upcoming_customer_ids.size
        when "frequent" then frequent_customer_ids.size
        when "pending_deposit" then pending_deposit_customer_ids.size
        when "new" then new_customer_ids.size
        when "no_show" then no_show_customer_ids.size
        else customers_scope.count
        end
      end

      def new_this_month_count
        customers_scope.where(created_at: Time.zone.today.beginning_of_month.beginning_of_day..Time.zone.today.end_of_month.end_of_day).count
      end

      def appointment_count_sort?
        sort.in?(%w[completed_appointments_asc completed_appointments_desc])
      end

      def sort_order
        case sort
        when "created_at_asc"
          "customer_profiles.created_at ASC, customer_profiles.id ASC"
        when "completed_appointments_asc"
          "COALESCE(customer_appointment_counts.appointments_count, 0) ASC, customer_profiles.created_at DESC, customer_profiles.id DESC"
        when "completed_appointments_desc"
          "COALESCE(customer_appointment_counts.appointments_count, 0) DESC, customer_profiles.created_at DESC, customer_profiles.id DESC"
        else
          "customer_profiles.created_at DESC, customer_profiles.id DESC"
        end
      end

      def appointment_count_join
        appointments = appointments_scope
          .where.not(status: Appointment.statuses[:canceled])
          .where.not(customer_profile_id: nil)
          .group(:customer_profile_id)
          .select(:customer_profile_id, "COUNT(*) AS appointments_count")

        <<~SQL.squish
          LEFT JOIN (#{appointments.to_sql}) AS customer_appointment_counts
            ON customer_appointment_counts.customer_profile_id = customer_profiles.id
        SQL
      end

      def frequent_grooming_customer_ids
        @frequent_grooming_customer_ids ||= appointments_scope
          .joins(:service)
          .where("services.category ILIKE :bano OR services.category ILIKE :corte OR services.category ILIKE :higiene OR services.name ILIKE :grooming", bano: "%Baño%", corte: "%Corte%", higiene: "%Higiene%", grooming: "%grooming%")
          .where.not(customer_profile_id: nil)
          .group(:customer_profile_id)
          .having("COUNT(*) >= 2")
          .count
          .keys
      end

      def gap_candidate_ids
        @gap_candidate_ids ||= (frequent_customer_ids + pending_deposit_customer_ids).uniq
      end
  end
end
