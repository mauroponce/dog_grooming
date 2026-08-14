module Admin
  class CalendarPresenter
    SLOT_MINUTES = 30
    DEFAULT_START_HOUR = 8
    DEFAULT_END_HOUR = 18
    SPANISH_MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze

    Metric = Struct.new(:label, :value, :hint, :tone, keyword_init: true)
    Column = Struct.new(:id, :label, :subtitle, :employee, keyword_init: true)
    Entry = Struct.new(:kind, :record, :starts_at, :ends_at, :employee, :title, :subtitle, :badge, :tone, :url, keyword_init: true)
    UrgencyPill = Struct.new(:label, :value, :tone, :url, :action_label, :external, keyword_init: true) do
      def active?
        value.to_i.positive?
      end

      def external?
        !!external
      end
    end
    AttentionItem = Struct.new(:title, :body, :tone, :url, :action_label, :external, keyword_init: true) do
      def external?
        !!external
      end
    end
    WeekDay = Struct.new(:date, :today, :selected, :appointments_count, :proofs_count, :pending_count, :cancelled_count, :first_appointment_time, :last_appointment_time, keyword_init: true)
    MonthDay = Struct.new(:date, :current_month, :today, :selected, :appointments_count, :proofs_count, :pending_count, :cancelled_count, keyword_init: true)

    attr_reader :business, :appointments_scope, :current_user, :params, :date, :view_mode, :query

    def initialize(business:, appointments_scope:, current_user:, params:)
      @business = business
      @appointments_scope = appointments_scope
      @current_user = current_user
      @params = params
      @date = parse_date(params[:calendar_date])
      @view_mode = parse_view_mode(params[:calendar_view])
      @query = params[:calendar_q].to_s.strip
    end

    def day_view?
      view_mode == "day"
    end

    def week_view?
      view_mode == "week"
    end

    def month_view?
      view_mode == "month"
    end

    def title
      return "Agenda del día" if day_view?
      return week_title if week_view?

      month_title
    end

    def subtitle
      if selected_employee.present?
        "#{selected_employee.display_name} · #{date_label}"
      else
        "Todos los profesionales · #{date_label}"
      end
    end

    def date_label
      return CustomerDateFormatter.date_label(date) if day_view?
      return week_title if week_view?

      month_title
    end

    def navigation_label
      return CustomerDateFormatter.date_label(date) if day_view?
      return week_title if week_view?

      month_title
    end

    def previous_date
      return date - 1.day if day_view?
      return date - 1.week if week_view?

      date.prev_month
    end

    def next_date
      return date + 1.day if day_view?
      return date + 1.week if week_view?

      date.next_month
    end

    def available_employees
      @available_employees ||= begin
        relation = business.employee_memberships.available_for_booking.with_attached_profile_photo.includes(user: { profile_photo_attachment: :blob }).order(:sort_order, :name)
        if owner_admin? || employee_can_view_all?
          relation.to_a
        else
          membership = current_user&.employee_membership_for(business)
          membership.present? ? relation.where(id: membership.id).to_a : []
        end
      end
    end

    def selected_employee
      @selected_employee ||= available_employees.find { |employee| employee.id.to_s == params[:calendar_employee_id].to_s }
    end

    def employee_options
      options = available_employees.map { |employee| [ employee.display_name, employee.id ] }
      can_view_all_professionals? ? [ [ "Todos los profesionales", "" ] ] + options : options
    end

    def columns
      @columns ||= begin
        if selected_employee.present?
          [ build_column(selected_employee) ]
        elsif column_employees.any?
          items = column_employees.map { |employee| build_column(employee) }
          items << Column.new(id: nil, label: "Sin asignar", subtitle: unassigned_subtitle, employee: nil) if unassigned_day_appointments?
          items
        else
          [ Column.new(id: nil, label: "Agenda del centro", subtitle: center_column_subtitle, employee: nil) ]
        end
      end
    end

    def metrics
      active = day_appointments.reject(&:canceled?)
      confirmed = active.count(&:confirmed?)
      items = [
        Metric.new(label: "Turnos", value: active.size, hint: "#{confirmed} confirmados", tone: :green),
        Metric.new(label: "Próximo", value: next_appointment_time, hint: next_appointment_hint, tone: next_appointment_tone),
        Metric.new(label: "Comprobantes", value: pending_proofs.size, hint: "para revisar", tone: :amber),
        Metric.new(label: "Huecos", value: fillable_gaps.size, hint: "para ofrecer", tone: :sky)
      ]
      items << Metric.new(label: "Caja estimada", value: format_currency(active.sum { |appointment| appointment.final_price_cents.to_i }), hint: "señas + saldos", tone: :zinc) if owner_admin?
      items
    end

    def urgency_pills
      [
        proof_pill,
        pending_deposit_pill,
        gap_pill
      ]
    end

    def day_entries
      @day_entries ||= (appointment_entries + block_entries + gap_entries).sort_by(&:starts_at)
    end

    def time_slots
      @time_slots ||= begin
        slots = []
        cursor = schedule_start
        while cursor < schedule_end
          slots << cursor
          cursor += SLOT_MINUTES.minutes
        end
        slots
      end
    end

    def day_grid_style
      min_width = 78 + (columns.size * 180)
      "grid-template-columns:78px repeat(#{columns.size},minmax(180px,1fr));grid-template-rows:68px repeat(#{time_slots.size},48px);min-width:#{min_width}px;width:100%;"
    end

    def day_entry_style(entry)
      column = column_index_for(entry.employee) + 2
      start_row = row_index_for(entry.starts_at) + 2
      span = [ ((entry.ends_at - entry.starts_at) / SLOT_MINUTES.minutes).ceil, 1 ].max
      "grid-column:#{column};grid-row:#{start_row} / span #{span};"
    end

    def week_days
      @week_days ||= begin
        counts = week_counts

        (date.beginning_of_week(:sunday)..date.end_of_week(:sunday)).map do |day|
          day_counts = counts.fetch(day, {})
          WeekDay.new(
            date: day,
            today: day == Time.zone.today,
            selected: day == date,
            appointments_count: day_counts.fetch(:appointments, 0),
            proofs_count: day_counts.fetch(:proofs, 0),
            pending_count: day_counts.fetch(:pending, 0),
            cancelled_count: day_counts.fetch(:cancelled, 0),
            first_appointment_time: day_counts[:first_appointment_time],
            last_appointment_time: day_counts[:last_appointment_time]
          )
        end
      end
    end

    def month_days
      @month_days ||= begin
        first_day = date.beginning_of_month
        last_day = date.end_of_month
        grid_start = first_day - first_day.wday.days
        grid_end = last_day + (6 - last_day.wday).days
        counts = month_counts

        (grid_start..grid_end).map do |day|
          day_counts = counts.fetch(day, {})
          MonthDay.new(
            date: day,
            current_month: day.month == date.month,
            today: day == Time.zone.today,
            selected: day == date,
            appointments_count: day_counts.fetch(:appointments, 0),
            proofs_count: day_counts.fetch(:proofs, 0),
            pending_count: day_counts.fetch(:pending, 0),
            cancelled_count: day_counts.fetch(:cancelled, 0)
          )
        end
      end
    end

    def next_operational_appointment
      @next_operational_appointment ||= begin
        appointments = day_appointments.reject(&:canceled?).sort_by(&:starts_at)
        if date == Time.zone.today
          appointments.find { |appointment| appointment.starts_at >= Time.current } || appointments.first
        else
          appointments.first
        end
      end
    end

    def attention_items
      @attention_items ||= [
        pending_proof_item,
        pending_deposit_item,
        fillable_gap_item
      ].compact
    end

    def legend_items
      [
        [ "Confirmado", "bg-emerald-500" ],
        [ "Comprobante", "bg-amber-500" ],
        [ "Seña pendiente", "bg-rose-500" ],
        [ "Hueco libre", "bg-sky-500" ],
        [ "Bloqueado", "bg-zinc-400" ]
      ]
    end

    def day_appointments
      @day_appointments ||= filter_appointment_relation(appointments_scope)
        .includes(:service, :branch, :bookable_resource, employee_membership: :user)
        .where(starts_at: day_range)
        .order(:starts_at)
        .to_a
    end

    private
      def parse_date(value)
        value.present? ? Date.iso8601(value.to_s) : Time.zone.today
      rescue Date::Error
        Time.zone.today
      end

      def parse_view_mode(value)
        mode = value.to_s
        %w[day week month].include?(mode) ? mode : "day"
      end

      def routes
        Rails.application.routes.url_helpers
      end

      def owner_admin?
        current_user&.admin? || current_user&.super_admin?
      end

      def can_review_deposits?
        return true if owner_admin?

        membership = current_user&.employee_membership_for(business)
        membership&.can?("can_approve_deposits") || membership&.can?("can_reject_deposits")
      end

      def employee_can_view_all?
        current_user&.employee_membership_for(business)&.can?("can_view_all_bookings")
      end

      def can_view_all_professionals?
        owner_admin? || employee_can_view_all?
      end

      def can_manage_availability?
        owner_admin? || current_user&.employee_membership_for(business)&.can?("can_manage_availability")
      end

      def column_employees
        @column_employees ||= begin
          employees = available_employees + day_appointments.map(&:employee_membership).compact
          employees.uniq(&:id)
        end
      end

      def filter_appointment_relation(relation)
        scoped = relation
        scoped = scoped.where(employee_membership: selected_employee) if selected_employee.present?
        if query.present?
          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
          phone_pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
          scoped = scoped.left_joins(:service).where(
            "LOWER(appointments.customer_name) LIKE :pattern OR appointments.customer_phone LIKE :phone_pattern OR LOWER(services.name) LIKE :pattern",
            pattern: pattern,
            phone_pattern: phone_pattern
          )
        end
        scoped
      end

      def day_range
        date.beginning_of_day..date.end_of_day
      end

      def month_range
        date.beginning_of_month.beginning_of_day..date.end_of_month.end_of_day
      end

      def week_range
        date.beginning_of_week(:sunday).beginning_of_day..date.end_of_week(:sunday).end_of_day
      end

      def week_title
        start_date = date.beginning_of_week(:sunday)
        end_date = date.end_of_week(:sunday)
        "Semana #{start_date.day}/#{start_date.month} - #{end_date.day}/#{end_date.month}"
      end

      def month_title
        "#{SPANISH_MONTHS.fetch(date.month - 1).capitalize} #{date.year}"
      end

      def build_column(employee)
        appointments = day_appointments.select { |appointment| appointment.employee_membership_id == employee.id }
        minutes = appointments.reject(&:canceled?).sum { |appointment| ((appointment.ends_at - appointment.starts_at) / 60).round }
        Column.new(
          id: employee.id,
          label: employee.display_name,
          subtitle: column_subtitle(appointments, minutes),
          employee: employee
        )
      end

      def column_subtitle(appointments, minutes)
        label = "#{appointments.size} #{appointments.size == 1 ? 'turno' : 'turnos'}"
        return "#{label} · libre" if minutes.zero?

        "#{label} · #{minutes} min"
      end

      def unassigned_subtitle
        "#{day_appointments.count { |appointment| appointment.employee_membership_id.blank? }} turnos"
      end

      def center_column_subtitle
        "#{day_appointments.size} turnos"
      end

      def unassigned_day_appointments?
        day_appointments.any? { |appointment| appointment.employee_membership_id.blank? }
      end

      def appointment_entries
        day_appointments.map do |appointment|
          Entry.new(
            kind: :appointment,
            record: appointment,
            starts_at: appointment.starts_at,
            ends_at: appointment.ends_at,
            employee: appointment.employee_membership,
            title: appointment.customer_name,
            subtitle: appointment_subtitle(appointment),
            badge: appointment_badge(appointment),
            tone: appointment_tone(appointment),
            url: routes.admin_appointment_path(appointment)
          )
        end
      end

      def block_entries
        raw_day_blocks.flat_map do |block|
          target_columns = if block.employee_membership.present?
            [ columns.find { |column| column.employee&.id == block.employee_membership_id } ].compact
          else
            columns
          end
          target_columns.map do |column|
            Entry.new(
              kind: :block,
              record: block,
              starts_at: [ block.starts_at, schedule_start ].max,
              ends_at: [ block.ends_at, schedule_end ].min,
              employee: column.employee,
              title: block.reason.presence || block.block_type_label,
              subtitle: block.block_type_label,
              badge: "Bloqueado",
              tone: :zinc,
              url: block_url
            )
          end
        end
      end

      def gap_entries
        fillable_gaps.first(8).map do |gap|
          service = gap.service_suggestions.first
          Entry.new(
            kind: :gap,
            record: gap,
            starts_at: gap.starts_at,
            ends_at: gap.ends_at,
            employee: gap.employee_membership,
            title: "#{gap.duration_minutes} min disponibles",
            subtitle: service.present? ? "Entra #{service.name}" : "Hueco libre",
            badge: "Hueco libre",
            tone: :sky,
            url: routes.admin_calendar_path(status: :today)
          )
        end
      end

      def fillable_gaps
        @fillable_gaps ||= Availability::FillableGaps.new(
          business: business,
          date: date,
          appointments_scope: appointments_scope,
          employee_membership: gap_employee
        ).call
      end

      def gap_employee
        return selected_employee if selected_employee.present?
        return available_employees.first if !owner_admin? && !employee_can_view_all? && available_employees.one?

        nil
      end

      def block_url
        routes.admin_calendar_path(status: :today)
      end

      def appointment_subtitle(appointment)
        appointment.service.name
      end

      def appointment_badge(appointment)
        return "Cancelado" if appointment.canceled?
        return "No asistió" if appointment.no_show?
        return "Reprogramado" if appointment.rescheduled?
        return "Vencido" if appointment.expired?
        return "Revisar comprobante" if appointment.pending_deposit_review? || appointment.deposit_status == "submitted"
        return "Pedir seña" if appointment.pending_deposit? || appointment.deposit_rejected? || deposit_pending?(appointment)
        return "Finalizar" if needs_completion?(appointment)
        return "Confirmar" if pending_without_required_deposit?(appointment)

        nil
      end

      def appointment_tone(appointment)
        return :zinc if appointment.canceled? || appointment.expired? || appointment.no_show? || appointment.rescheduled?
        return :amber if appointment.pending_deposit_review? || appointment.deposit_status == "submitted"
        return :rose if appointment.pending_deposit? || appointment.deposit_rejected? || deposit_pending?(appointment)
        return :brand if needs_completion?(appointment) || pending_without_required_deposit?(appointment)
        return :emerald if appointment.confirmed? || appointment.completed? || appointment.deposit_status == "approved"

        :brand
      end

      def deposit_pending?(appointment)
        appointment.deposit_required? && appointment.deposit_status.in?(%w[pending rejected failed]) && !appointment.confirmed?
      end

      def pending_without_required_deposit?(appointment)
        !appointment.deposit_required? && !appointment.terminal_status? && !appointment.confirmed?
      end

      def needs_completion?(appointment)
        appointment.confirmed? && appointment.starts_at < Time.current
      end

      def pending_proofs
        @pending_proofs ||= day_appointments.select(&:pending_deposit_review?)
      end

      def pending_deposit_appointments
        @pending_deposit_appointments ||= day_appointments.reject(&:canceled?).select { |booking| booking.pending_deposit? || booking.deposit_rejected? }
      end

      def proof_pill
        appointment = pending_proofs.first
        UrgencyPill.new(
          label: pending_proofs.size == 1 ? "comprobante" : "comprobantes",
          value: pending_proofs.size,
          tone: pending_proofs.any? ? :amber : :zinc,
          url: proof_url_for(appointment),
          action_label: pending_proofs.any? ? "Revisar" : nil
        )
      end

      def pending_deposit_pill
        appointment = pending_deposit_appointments.first
        UrgencyPill.new(
          label: pending_deposit_appointments.size == 1 ? "sin seña" : "sin seña",
          value: pending_deposit_appointments.size,
          tone: pending_deposit_appointments.any? ? :rose : :zinc,
          url: appointment&.manual_whatsapp_url,
          action_label: pending_deposit_appointments.any? ? "Pedir seña" : nil,
          external: appointment.present?
        )
      end

      def gap_pill
        gap = fillable_gaps.first
        UrgencyPill.new(
          label: fillable_gaps.size == 1 ? "hueco" : "huecos",
          value: fillable_gaps.size,
          tone: fillable_gaps.any? ? :sky : :zinc,
          url: gap.present? ? routes.admin_calendar_path(status: :today) : nil,
          action_label: fillable_gaps.any? ? "Ver huecos" : nil
        )
      end

      def proof_url_for(appointment)
        return if appointment.blank?
        return routes.admin_appointment_path(appointment) if can_review_deposits?

        routes.admin_appointment_path(appointment)
      end

      def entry_minutes
        @entry_minutes ||= begin
          appointment_times = day_appointments.flat_map { |appointment| [ appointment.starts_at, appointment.ends_at ] }
          block_times = raw_day_blocks.flat_map { |block| [ block.starts_at, block.ends_at ] }
          gap_times = fillable_gaps.flat_map { |gap| [ gap.starts_at, gap.ends_at ] }
          appointment_times + block_times + gap_times
        end
      end

      def schedule_start
        @schedule_start ||= round_down_to_slot([ availability_start, entry_minutes.min, default_start_time ].compact.min)
      end

      def schedule_end
        @schedule_end ||= begin
          value = round_up_to_slot([ availability_end, entry_minutes.max, default_end_time ].compact.max)
          value <= schedule_start ? schedule_start + SLOT_MINUTES.minutes : value
        end
      end

      def raw_day_blocks
        @raw_day_blocks ||= begin
          blocks = business.availability_blocks.active.overlapping(day_range.begin, day_range.end)
          blocks = blocks.where("employee_membership_id IS NULL OR employee_membership_id = ?", selected_employee.id) if selected_employee.present?
          if !owner_admin? && !employee_can_view_all? && available_employees.one?
            employee = available_employees.first
            blocks = blocks.where("employee_membership_id IS NULL OR employee_membership_id = ?", employee.id)
          end
          blocks.to_a
        end
      end

      def availability_start
        availability_windows.map(&:first).compact.min
      end

      def availability_end
        availability_windows.map(&:last).compact.max
      end

      def availability_windows
        @availability_windows ||= columns.filter_map do |column|
          rule = availability_rule_for(column.employee)
          next unless rule&.active? && rule.start_time.present? && rule.end_time.present?

          [ time_on_date(rule.start_time), time_on_date(rule.end_time) ]
        end
      end

      def availability_rule_for(employee)
        business_rule = business.availability_rules.find_by(weekday: date.wday)
        return business_rule if employee.blank?

        employee_rule = employee.employee_availability_rules.find_by(weekday: date.wday)
        employee_rule&.inherits_business_hours? ? business_rule : (employee_rule || business_rule)
      end

      def time_on_date(value)
        Time.zone.local(date.year, date.month, date.day, value.hour, value.min)
      end

      def default_start_time
        Time.zone.local(date.year, date.month, date.day, DEFAULT_START_HOUR, 0)
      end

      def default_end_time
        Time.zone.local(date.year, date.month, date.day, DEFAULT_END_HOUR, 0)
      end

      def round_down_to_slot(time)
        minute = (time.min / SLOT_MINUTES) * SLOT_MINUTES
        time.change(min: minute, sec: 0)
      end

      def round_up_to_slot(time)
        remainder = time.min % SLOT_MINUTES
        rounded = remainder.zero? ? time : time + (SLOT_MINUTES - remainder).minutes
        rounded.change(sec: 0)
      end

      def row_index_for(time)
        [[ ((time - schedule_start) / SLOT_MINUTES.minutes).floor, 0 ].max, time_slots.size - 1].min
      end

      def column_index_for(employee)
        index = columns.index { |column| column.employee&.id == employee&.id }
        index || columns.index { |column| column.employee.blank? } || 0
      end

      def month_counts
        month_appointments.each_with_object({}) do |appointment, counts|
          key = appointment.starts_at.to_date
          counts[key] ||= Hash.new(0)
          counts[key][:appointments] += 1 unless appointment.canceled?
          counts[key][:proofs] += 1 if appointment.pending_deposit_review?
          counts[key][:pending] += 1 if appointment.pending_deposit? || appointment.deposit_rejected?
          counts[key][:cancelled] += 1 if appointment.canceled?
        end
      end

      def week_counts
        week_appointments.each_with_object({}) do |appointment, counts|
          key = appointment.starts_at.to_date
          counts[key] ||= {
            appointments: 0,
            proofs: 0,
            pending: 0,
            cancelled: 0,
            first_appointment_time: nil,
            last_appointment_time: nil
          }
          counts[key][:appointments] += 1 unless appointment.canceled?
          counts[key][:proofs] += 1 if appointment.pending_deposit_review?
          counts[key][:pending] += 1 if appointment.pending_deposit? || appointment.deposit_rejected?
          counts[key][:cancelled] += 1 if appointment.canceled?
          counts[key][:first_appointment_time] = appointment.starts_at if counts[key][:first_appointment_time].blank? || appointment.starts_at < counts[key][:first_appointment_time]
          counts[key][:last_appointment_time] = appointment.starts_at if counts[key][:last_appointment_time].blank? || appointment.starts_at > counts[key][:last_appointment_time]
        end
      end

      def week_appointments
        @week_appointments ||= filter_appointment_relation(appointments_scope)
          .where(starts_at: week_range)
          .order(:starts_at)
          .to_a
      end

      def month_appointments
        @month_appointments ||= filter_appointment_relation(appointments_scope)
          .where(starts_at: month_range)
          .to_a
      end

      def next_appointment_time
        next_operational_appointment.present? ? CustomerDateFormatter.time_label(next_operational_appointment.starts_at).delete_suffix(" hs") : "Libre"
      end

      def next_appointment_hint
        next_operational_appointment.present? ? next_operational_appointment.service.name : "sin turnos"
      end

      def next_appointment_tone
        next_operational_appointment.present? ? appointment_tone(next_operational_appointment) : :zinc
      end

      def pending_proof_item
        appointment = day_appointments.find(&:pending_deposit_review?)
        return if appointment.blank?

        AttentionItem.new(
          title: "Comprobante para revisar",
          body: "#{appointment.customer_name} · #{CustomerDateFormatter.time_label(appointment.starts_at).delete_suffix(' hs')}",
          tone: :amber,
          url: routes.admin_appointment_path(appointment),
          action_label: "Revisar"
        )
      end

      def pending_deposit_item
        appointment = day_appointments.find { |booking| booking.pending_deposit? || booking.deposit_rejected? }
        return if appointment.blank?

        AttentionItem.new(
          title: "Seña pendiente",
          body: "#{appointment.customer_name} · #{CustomerDateFormatter.time_label(appointment.starts_at).delete_suffix(' hs')}",
          tone: :rose,
          url: appointment.manual_whatsapp_url,
          action_label: "Pedir seña",
          external: true
        )
      end

      def fillable_gap_item
        gap = fillable_gaps.first
        return if gap.blank?

        AttentionItem.new(
          title: "Hueco para ofrecer",
          body: "#{CustomerDateFormatter.time_label(gap.starts_at).delete_suffix(' hs')} · #{gap.duration_minutes} min disponibles",
          tone: :sky,
          url: routes.admin_calendar_path(status: :today),
          action_label: "Ver huecos"
        )
      end

      def format_currency(cents)
        amount = cents.to_i / 100.0
        precision = (cents.to_i % 100).zero? ? 0 : 2
        ActiveSupport::NumberHelper.number_to_currency(amount, unit: "$", precision:, delimiter: ".", separator: ",")
      end
  end
end
