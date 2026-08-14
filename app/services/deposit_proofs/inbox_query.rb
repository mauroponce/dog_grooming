module DepositProofs
  class InboxQuery
    Metric = Struct.new(:label, :value, :hint, :tone, keyword_init: true)
    StatusFilter = Struct.new(:key, :label, :count, :active, keyword_init: true)

    STATUS_FILTERS = {
      "all" => "Todos",
      "pending" => "En revisión",
      "approved" => "Aprobados",
      "rejected" => "Rechazados",
      "expired" => "Vencidos"
    }.freeze

    attr_reader :business, :appointments_scope, :params, :date

    def initialize(business:, appointments_scope:, params:, date: Time.zone.today)
      @business = business
      @appointments_scope = appointments_scope
      @params = params
      @date = date.to_date
    end

    def status
      STATUS_FILTERS.key?(params[:status].to_s) ? params[:status].to_s : "all"
    end

    def query
      params[:q].to_s.strip
    end

    def date_from
      parse_date(params[:date_from]) || date.beginning_of_week
    end

    def date_to
      parse_date(params[:date_to]) || date.end_of_week
    end

    def range
      date_from.beginning_of_day..date_to.end_of_day
    end

    def proofs
      @proofs ||= proofs_relation.to_a
    end

    def proofs_relation
      @proofs_relation ||= apply_filters(proof_base)
        .includes(:service, :customer_profile, :bookable_resource, :branch, :deposit_reviewed_by, deposit_receipt_attachment: :blob, employee_membership: :user)
        .order(ordering)
    end

    def selected_proof
      @selected_proof ||= begin
        selected = if params[:proof_id].present?
          proof_base
            .includes(:service, :customer_profile, :bookable_resource, :branch, :deposit_reviewed_by, deposit_receipt_attachment: :blob, employee_membership: :user)
            .find_by(id: params[:proof_id])
        end
        selected || proofs.first
      end
    end

    def metrics
      [
        Metric.new(label: "En revisión", value: pending_scope.count, hint: "para revisar", tone: :amber),
        Metric.new(label: "Aprobados hoy", value: approved_scope.where(deposit_reviewed_at: date.all_day).count, hint: "confirmados", tone: :green),
        Metric.new(label: "Señas registradas", value: format_currency(approved_scope.where(deposit_reviewed_at: range).sum(:deposit_amount_cents)), hint: "rango", tone: :violet),
        Metric.new(label: "Rechazados", value: rejected_scope.where(deposit_reviewed_at: range).count, hint: "rango", tone: :rose)
      ]
    end

    def status_filters
      STATUS_FILTERS.map do |key, label|
        StatusFilter.new(key:, label:, count: count_for_status(key), active: key == status)
      end
    end

    def services
      business.services.active.order(:name)
    end

    def employees
      return EmployeeMembership.none unless business.team_features_available?

      business.employee_memberships.active.order(:name)
    end

    def team_plan?
      business.team_features_available?
    end

    def pending_count
      pending_scope.count
    end

    def to_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << [ "Cliente", "WhatsApp", "Servicio", "Turno", "Profesional", "Estado", "Seña esperada", "Total", "Método informado" ]
        proofs.each do |appointment|
          csv << [
            appointment.customer_name,
            appointment.customer_phone,
            appointment.service.name,
            CustomerDateFormatter.datetime_label(appointment.starts_at),
            appointment.employee_membership&.name,
            appointment.deposit_status_label,
            appointment.formatted_deposit_amount,
            format_currency(appointment.final_price_cents),
            payment_method_label(appointment)
          ]
        end
      end
    end

    def payment_method_label(appointment)
      return "Carga manual" if appointment.manual?
      return "Enlace externo" if appointment.service.external_payment_link.present? && appointment.service.deposit_payment_details.blank?
      return "Enlace externo" if business.deposit_payment_link.present? && appointment.service.deposit_payment_details.blank?

      "Transferencia"
    end

    private
      def proof_base
        @proof_base ||= appointments_scope
          .where.not(deposit_status: "not_required")
          .where(
            "appointments.deposit_status IN (:statuses) OR appointments.status = :expired",
            statuses: %w[submitted approved rejected],
            expired: Appointment.statuses[:expired]
          )
      end

      def apply_filters(relation)
        relation = apply_status(relation)
        relation = apply_search(relation)
        relation = relation.where(starts_at: range) if date_filter_applied?
        relation = relation.where(service_id: params[:service_id]) if params[:service_id].present?
        relation = relation.where(employee_membership_id: params[:employee_membership_id]) if team_plan? && params[:employee_membership_id].present?
        relation = apply_method(relation)
        relation
      end

      def apply_status(relation)
        case status
        when "pending"
          relation.where("appointments.deposit_status = ? OR appointments.status = ?", "submitted", Appointment.statuses[:pending_deposit_review])
        when "approved"
          relation.where(deposit_status: "approved")
        when "rejected"
          relation.where(deposit_status: "rejected")
        when "expired"
          relation.where(status: Appointment.statuses[:expired])
        else
          relation
        end
      end

      def apply_search(relation)
        return relation if query.blank?

        needle = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        relation
          .joins(:service)
          .left_joins(:employee_membership)
          .where(
            "appointments.customer_name ILIKE :needle OR appointments.customer_phone ILIKE :needle OR services.name ILIKE :needle OR employee_memberships.name ILIKE :needle",
            needle:
          )
      end

      def apply_method(relation)
        case params[:payment_method].to_s
        when "manual_upload"
          relation.where(source: Appointment.sources[:manual])
        when "manual_transfer", "external_payment_link"
          relation.where(source: Appointment.sources[:public_booking])
        else
          relation
        end
      end

      def pending_scope
        proof_base.where("appointments.deposit_status = ? OR appointments.status = ?", "submitted", Appointment.statuses[:pending_deposit_review])
      end

      def approved_scope
        proof_base.where(deposit_status: "approved")
      end

      def rejected_scope
        proof_base.where(deposit_status: "rejected")
      end

      def count_for_status(key)
        case key
        when "pending" then pending_scope.count
        when "approved" then approved_scope.count
        when "rejected" then rejected_scope.count
        when "expired" then proof_base.where(status: Appointment.statuses[:expired]).count
        else proof_base.count
        end
      end

      def ordering
        sanitized_order = ActiveRecord::Base.sanitize_sql_array([ <<~SQL.squish, Time.zone.tzinfo.name, date.iso8601 ])
          CASE
            WHEN DATE(appointments.starts_at AT TIME ZONE 'UTC' AT TIME ZONE ?) = ?
              AND appointments.deposit_status = 'submitted' THEN 0
            WHEN appointments.deposit_status = 'submitted' THEN 1
            ELSE 2
          END,
          appointments.deposit_submitted_at DESC NULLS LAST,
          appointments.starts_at ASC
        SQL
        Arel.sql(sanitized_order)
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def date_filter_applied?
        params[:date_from].present? || params[:date_to].present?
      end

      def format_currency(cents)
        "$#{ActiveSupport::NumberHelper.number_to_delimited(cents.to_i / 100, delimiter: ".")}"
      end
  end
end
