require "csv"

module SuperAdmin
  class Dashboard
    FILTERS = [
      [ "all", "Todos" ],
      [ "trial", "Trials" ],
      [ "active", "Activos" ],
      [ "pending_review", "En revisión" ],
      [ "overdue", "Vencidos" ],
      [ "restricted", "Restringidos" ],
      [ "free", "Gratis" ],
      [ "needs_setup", "Setup" ]
    ].freeze

    Metric = Struct.new(:label, :value, :badge, :description, :tone, keyword_init: true)
    AttentionItem = Struct.new(:title, :body, :tone, :count, keyword_init: true)
    SystemItem = Struct.new(:label, :value, :tone, keyword_init: true)
    ActivityItem = Struct.new(:title, :body, :tone, :time, keyword_init: true)

    attr_reader :params

    def initialize(params:)
      @params = params
      @businesses = Business.includes(:owner, :subscription, :billing_reminders, subscription_invoices: :subscription_payment_proofs).order(created_at: :desc).to_a
      @stats = build_stats
      @rows = @businesses.map { |business| BusinessRow.new(business, stats_for(business.id)) }
    end

    def q
      params[:q].to_s.strip
    end

    def filter
      requested = params[:filter].to_s
      FILTERS.map(&:first).include?(requested) ? requested : "all"
    end

    def rows
      @rows.select { |row| matches_filter?(row) && matches_query?(row) }
    end

    def all_rows
      @rows
    end

    def selected_row
      selected_id = params[:business_id].presence&.to_i
      all_rows.find { |row| row.id == selected_id } || all_rows.first
    end

    def metrics
      [
        Metric.new(
          label: "Negocios",
          value: all_rows.count,
          badge: "+#{businesses_created_this_month} mes",
          description: "#{active_count} activos · #{trial_count} trial · #{disabled_count} pausa",
          tone: :emerald
        ),
        Metric.new(
          label: "MRR",
          value: money_label(mrr_cents),
          badge: "#{active_count} activos",
          description: "Precio promedio #{money_label(average_revenue_cents)}",
          tone: :emerald
        ),
        Metric.new(
          label: "Trials",
          value: trial_count,
          badge: "#{trials_ending_soon_count} vencen",
          description: "#{trial_setup_complete_count} con setup completo",
          tone: :amber
        ),
        Metric.new(
          label: "Pagos",
          value: overdue_count,
          badge: "Vencidos",
          description: "#{money_label(overdue_cents)} por cobrar",
          tone: :rose
        ),
        Metric.new(
          label: "Reservas hoy",
          value: bookings_today_count,
          badge: "Hoy",
          description: "En toda la plataforma",
          tone: :brand
        ),
        Metric.new(
          label: "Errores",
          value: platform_errors_count,
          badge: platform_errors_count.positive? ? "Atender" : "OK",
          description: "#{failed_email_count} email · #{failed_jobs_count} jobs",
          tone: platform_errors_count.positive? ? :rose : :emerald
        )
      ]
    end

    def attention_items
      [
        AttentionItem.new(
          title: "#{trials_ending_soon_count} trials vencen en 48 hs",
          body: "Enviar mensaje de conversión o extender prueba.",
          tone: :amber,
          count: trials_ending_soon_count
        ),
        AttentionItem.new(
          title: "#{overdue_count} pagos vencidos",
          body: "#{money_label(overdue_cents)} pendientes de confirmar.",
          tone: :rose,
          count: overdue_count
        ),
        AttentionItem.new(
          title: "#{needs_setup_count} negocios con setup incompleto",
          body: "Revisar servicios públicos, agenda, perfil y configuración inicial.",
          tone: :sky,
          count: needs_setup_count
        ),
        AttentionItem.new(
          title: "#{failed_email_count} errores de email",
          body: "Revisar dominio, remitente o permisos de Resend.",
          tone: :brand,
          count: failed_email_count
        )
      ]
    end

    def attention_count
      attention_items.sum(&:count)
    end

    def billing_rows
      [
        [ "Activas", "Pagando actualmente", active_count, :zinc ],
        [ "Trial", "Dentro del periodo de prueba", trial_count, :zinc ],
        [ "En revisión", "Comprobantes subidos", pending_review_count, :brand ],
        [ "Vencidas", "Pendientes de pago", overdue_count, :rose ],
        [ "Restringidas", "Reservas online pausadas", restricted_count, :rose ]
      ]
    end

    def system_items
      [
        SystemItem.new(label: "App", value: "OK", tone: :emerald),
        SystemItem.new(label: "Postgres", value: "#{postgres_connections_count} conexiones", tone: :emerald),
        SystemItem.new(label: "Jobs", value: "#{failed_jobs_count} fallidos", tone: failed_jobs_count.positive? ? :amber : :emerald),
        SystemItem.new(label: "Resend", value: "#{failed_email_count} fallos", tone: failed_email_count.positive? ? :rose : :emerald),
        SystemItem.new(label: "R2 Storage", value: storage_label(total_storage_bytes), tone: :emerald)
      ]
    end

    def recent_activity
      events = []
      Business.order(created_at: :desc).limit(2).includes(:owner).each do |business|
        events << ActivityItem.new(
          title: "Nuevo negocio registrado",
          body: "#{business.name} · #{business.owner.email_address}",
          tone: :emerald,
          time: business.created_at
        )
      end

      Subscription.where.not(last_payment_at: nil).includes(:business).order(last_payment_at: :desc).limit(1).each do |subscription|
        events << ActivityItem.new(
          title: "Suscripción actualizada",
          body: "#{subscription.business.name} · #{subscription.status}",
          tone: :brand,
          time: subscription.last_payment_at
        )
      end

      EmailDeliveryLog.where(status: "failed").order(created_at: :desc).limit(1).each do |log|
        events << ActivityItem.new(
          title: "Email fallido",
          body: "#{log.mailer}##{log.action} · #{log.recipient}",
          tone: :rose,
          time: log.created_at
        )
      end

      events.sort_by { |event| event.time || Time.zone.at(0) }.reverse.first(4)
    end

    def to_csv
      CSV.generate(headers: true) do |csv|
        csv << [
          "Negocio",
          "Slug",
          "Admin",
          "Ciudad",
          "Estado",
          "Setup",
          "Turnos 30d",
          "Comprobantes 30d",
          "Profesionales",
          "Suscripcion",
          "Mensual $",
          "Trial vence",
          "Creado"
        ]

        rows.each do |row|
          csv << [
            row.name,
            row.slug,
            row.admin_email,
            row.city,
            row.status_label,
            "#{row.setup_score}%",
            row.bookings_30d_count,
            row.proofs_30d_count,
            row.professionals_count,
            row.subscription_label,
            row.monthly_amount_cents / 100,
            row.business.trial_ends_at&.to_date,
            row.business.created_at&.to_date
          ]
        end
      end
    end

    private
      def build_stats
        ids = @businesses.map(&:id)
        return empty_stats if ids.empty?

        {
          appointments_30d: Appointment.where(business_id: ids).where("starts_at >= ?", 30.days.ago).group(:business_id).count,
          appointments_today: Appointment.where(business_id: ids, starts_at: Time.zone.today.all_day).group(:business_id).count,
          proofs_30d: Appointment.where(business_id: ids).where.not(deposit_status: "not_required").where("created_at >= ?", 30.days.ago).group(:business_id).count,
          employees: EmployeeMembership.active.where(business_id: ids, archived_at: nil).group(:business_id).count,
          services: Service.active.where(business_id: ids).group(:business_id).count,
          public_services: Service.publicly_bookable.where(business_id: ids).group(:business_id).count,
          failed_emails: EmailDeliveryLog.where(business_id: ids, status: "failed").where("created_at >= ?", 30.days.ago).group(:business_id).count,
          last_activity: Appointment.where(business_id: ids).group(:business_id).maximum(:updated_at),
          storage_bytes: storage_bytes_by_business(ids)
        }
      end

      def empty_stats
        {
          appointments_30d: {},
          appointments_today: {},
          proofs_30d: {},
          employees: {},
          services: {},
          public_services: {},
          failed_emails: {},
          last_activity: {},
          storage_bytes: {}
        }
      end

      def stats_for(business_id)
        {
          appointments_30d: @stats.fetch(:appointments_30d).fetch(business_id, 0),
          appointments_today: @stats.fetch(:appointments_today).fetch(business_id, 0),
          proofs_30d: @stats.fetch(:proofs_30d).fetch(business_id, 0),
          employees: @stats.fetch(:employees).fetch(business_id, 0),
          services: @stats.fetch(:services).fetch(business_id, 0),
          public_services: @stats.fetch(:public_services).fetch(business_id, 0),
          failed_emails: @stats.fetch(:failed_emails).fetch(business_id, 0),
          last_activity: @stats.fetch(:last_activity)[business_id],
          storage_bytes: @stats.fetch(:storage_bytes).fetch(business_id, 0)
        }
      end

      def storage_bytes_by_business(ids)
        totals = Hash.new(0)
        totals.merge!(attachment_bytes_for("Business", ids))
        totals.merge!(attachment_bytes_for_join("Appointment", "appointments", ids)) { |_key, old, value| old + value }
        totals.merge!(attachment_bytes_for_join("Service", "services", ids)) { |_key, old, value| old + value }
        totals
      rescue StandardError
        {}
      end

      def attachment_bytes_for(record_type, record_ids)
        ActiveStorage::Attachment.joins(:blob)
          .where(record_type: record_type, record_id: record_ids)
          .group(:record_id)
          .sum("active_storage_blobs.byte_size")
      end

      def attachment_bytes_for_join(record_type, table_name, business_ids)
        ActiveStorage::Attachment.joins(:blob)
          .joins("INNER JOIN #{table_name} ON #{table_name}.id = active_storage_attachments.record_id")
          .where(record_type: record_type, table_name => { business_id: business_ids })
          .group("#{table_name}.business_id")
          .sum("active_storage_blobs.byte_size")
      end

      def matches_filter?(row)
        filter == "all" || row.status_key == filter
      end

      def matches_query?(row)
        return true if q.blank?

        row.search_text.include?(q.downcase)
      end

      def active_count
        all_rows.count(&:active?)
      end

      def disabled_count
        all_rows.count(&:disabled?)
      end

      def trial_count
        all_rows.count(&:trial?)
      end

      def overdue_count
        all_rows.count(&:overdue?)
      end

      def pending_review_count
        all_rows.count(&:pending_review?)
      end

      def restricted_count
        all_rows.count(&:restricted?)
      end

      def needs_setup_count
        all_rows.count(&:needs_setup?)
      end

      def businesses_created_this_month
        all_rows.count { |row| row.business.created_at >= Time.zone.now.beginning_of_month }
      end

      def mrr_cents
        all_rows.select(&:active?).sum(&:monthly_amount_cents)
      end

      def overdue_cents
        all_rows.select(&:overdue?).sum(&:monthly_amount_cents)
      end

      def average_revenue_cents
        return 0 if active_count.zero?

        mrr_cents / active_count
      end

      def trial_setup_complete_count
        all_rows.count { |row| row.trial? && row.setup_score >= 85 }
      end

      def trials_ending_soon_count
        all_rows.count do |row|
          row.trial? && row.business.trial_ends_at.present? && row.business.trial_ends_at <= 48.hours.from_now
        end
      end

      def bookings_today_count
        @stats.fetch(:appointments_today).values.sum
      end

      def failed_email_count
        return 0 unless ActiveRecord::Base.connection.data_source_exists?(EmailDeliveryLog.table_name)

        EmailDeliveryLog.where(status: "failed").where("created_at >= ?", 30.days.ago).count
      end

      def failed_jobs_count
        return 0 unless defined?(SolidQueue::FailedExecution)
        return 0 unless ActiveRecord::Base.connection.data_source_exists?(SolidQueue::FailedExecution.table_name)

        SolidQueue::FailedExecution.count
      rescue StandardError
        0
      end

      def platform_errors_count
        failed_email_count + failed_jobs_count
      end

      def postgres_connections_count
        ActiveRecord::Base.connection.select_value("SELECT count(*) FROM pg_stat_activity").to_i
      rescue StandardError
        0
      end

      def total_storage_bytes
        @stats.fetch(:storage_bytes).values.sum
      end

      def money_label(cents)
        amount = cents.to_i / 100
        return "$0" if amount.zero?
        return "$#{amount / 1_000}k" if amount >= 100_000 && (amount % 1_000).zero?

        "$#{amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
      end

      def storage_label(bytes)
        return "0 MB" if bytes.to_i.zero?

        ActiveSupport::NumberHelper.number_to_human_size(bytes)
      end
  end

  class Dashboard::BusinessRow
    OVERDUE_STATUSES = %w[overdue past_due expired failed payment_pending payment_due].freeze

    attr_reader :business, :stats

    def initialize(business, stats)
      @business = business
      @stats = stats
    end

    delegate :id, :name, :slug, to: :business

    def admin_email
      business.owner.email_address
    end

    def city
      business.city.presence || business.neighborhood.presence || business.province.presence || "Sin ciudad"
    end

    def status_key
      return "free" unless business.billing_enabled?
      return "disabled" if disabled? || suspended?
      return "restricted" if restricted?
      return "pending_review" if pending_review?
      return "overdue" if overdue?
      return "needs_setup" if needs_setup?
      return "active" if active?
      return "trial" if trial?

      "overdue"
    end

    def status_label
      {
        "active" => "Activo",
        "trial" => "Trial",
        "pending_review" => "Pago en revisión",
        "overdue" => "Pago vencido",
        "restricted" => "Restringido",
        "free" => "Gratis",
        "needs_setup" => "Setup incompleto",
        "disabled" => "Suspendido"
      }.fetch(status_key)
    end

    def active?
      business.billing_status == "active"
    end

    def trial?
      !active? && !overdue? && business.trial_active?
    end

    def overdue?
      return false if pending_review? || restricted? || suspended?
      return true if OVERDUE_STATUSES.include?(business.subscription&.normalized_status || business.subscription&.status)
      return false if business.subscription_active? || business.trial_active? || business.trial_grace_period_active?

      business.trial_ends_at.present? && business.trial_ends_at.past?
    end

    def pending_review?
      business.subscription&.pending_review?
    end

    def restricted?
      business.subscription&.restricted?
    end

    def suspended?
      business.subscription&.suspended? || business.subscription&.cancelled?
    end

    def disabled?
      business.disabled?
    end

    def needs_setup?
      setup_score < 70
    end

    def setup_score
      score = 0
      score += 20 if business.onboarding_complete?
      score += 20 if public_services_count.positive?
      score += 15 if active_services_count.positive?
      score += 15 if professionals_count.positive?
      score += 10 if business.contact_phone.present? || business.phone.present?
      score += 10 if business.availability_rules.where(active: true).exists?
      [ score, 100 ].min
    end

    def bookings_30d_count
      stats.fetch(:appointments_30d).to_i
    end

    def proofs_30d_count
      stats.fetch(:proofs_30d).to_i
    end

    def professionals_count
      stats.fetch(:employees).to_i
    end

    def active_services_count
      stats.fetch(:services).to_i
    end

    def public_services_count
      stats.fetch(:public_services).to_i
    end

    def failed_email_count
      stats.fetch(:failed_emails).to_i
    end

    def storage_bytes
      stats.fetch(:storage_bytes).to_i
    end

    def last_activity_at
      stats.fetch(:last_activity).presence || business.updated_at
    end

    def monthly_amount_cents
      business.monthly_amount_cents
    end

    def subscription_label
      return "Suspendida" if disabled? || suspended?
      return "Restringida" if restricted?
      return "En revisión" if pending_review?
      return "Vencida" if overdue?
      return "Activa" if active?
      return "Vence en #{business.trial_days_remaining} días" if trial?

      business.subscription&.normalized_status.to_s.humanize
    end

    def current_invoice
      @current_invoice ||= business.subscription&.current_invoice
    end

    def current_payment_proof
      @current_payment_proof ||= current_invoice&.current_proof
    end

    def billing_due_label
      return "Sin cobro" if current_invoice.blank?

      CustomerDateFormatter.date_label(current_invoice.due_on)
    end

    def last_billing_reminder_at
      business.billing_reminders.select { |reminder| reminder.channel == "email" }.max_by(&:sent_at)&.sent_at
    end

    def days_overdue
      current_invoice&.days_overdue.to_i
    end

    def flags
      values = []
      values << "Revisar pago" if pending_review?
      values << "Cobrar" if overdue?
      values << "Pausado" if restricted? || suspended?
      values << "Convertir" if trial?
      values << "Sin servicios" if public_services_count.zero?
      values << "Email" if failed_email_count.positive?
      values << "Buen uso" if values.blank? && bookings_30d_count.positive?
      values.presence || [ "Nuevo" ]
    end

    def search_text
      [
        name,
        slug,
        admin_email,
        city,
        status_label,
        subscription_label,
        flags.join(" ")
      ].join(" ").downcase
    end
  end
end
