module Customers
  class ProfilePresenter
    ProfileMetric = Struct.new(:label, :value, :tone, keyword_init: true)
    StatusChip = Struct.new(:label, :tone, keyword_init: true)
    Opportunity = Struct.new(:title, :body, :url, :tone, :action_label, keyword_init: true)

    attr_reader :customer, :business, :appointments_scope, :current_user

    def initialize(customer:, business:, appointments_scope:, current_user:, appointments: nil)
      @customer = customer
      @business = business
      @appointments_scope = appointments_scope
      @current_user = current_user
      @preloaded_appointments = appointments
    end

    def name
      customer.name.presence || "Sin nombre"
    end

    def initials
      parts = name.split
      return customer.phone.last(2) if parts.blank?

      parts.first(2).map { |part| part.first.upcase }.join
    end

    def appointments
      @appointments ||= @preloaded_appointments || appointments_scope
        .where(customer_profile: customer)
        .includes(:service, :bookable_resource, :branch, booking_notes: :created_by, booking_attachments: { file_attachment: :blob }, employee_membership: :user)
        .order(starts_at: :desc)
        .to_a
    end

    def next_appointment
      @next_appointment ||= appointments.select { |appointment| appointment.starts_at.future? && !appointment.canceled? && !appointment.expired? }.min_by(&:starts_at)
    end

    def history
      @history ||= appointments.select { |appointment| appointment.starts_at.past? || appointment.canceled? || appointment.expired? }.first(8)
    end

    def notes
      @notes ||= customer.client_notes.includes(:user).order(created_at: :desc).limit(6)
    end

    def reminders
      @reminders ||= customer.customer_reminders.includes(:assigned_to).recent_first.limit(6)
    end

    def total_appointments
      appointments.size
    end

    def last_visit
      @last_visit ||= appointments.select { |appointment| appointment.starts_at.past? && (appointment.completed? || appointment.confirmed?) }.max_by(&:starts_at)
    end

    def last_visit_label
      return "Sin visitas" unless last_visit

      distance_label(last_visit.starts_at)
    end

    def next_appointment_label
      return "Sin próximo turno" unless next_appointment

      "#{next_appointment.service.name} · #{CustomerDateFormatter.datetime_label(next_appointment.starts_at)}"
    end

    def estimated_spend_label
      cents = appointments.reject(&:canceled?).sum(&:final_price_cents)
      "$#{ActiveSupport::NumberHelper.number_to_delimited(cents.to_i / 100, delimiter: ".")}"
    end

    def primary_status_label
      status_chips.first&.label || "Activo"
    end

    def profile_metrics
      [
        ProfileMetric.new(label: "Turnos", value: total_appointments, tone: :zinc),
        ProfileMetric.new(label: "Última visita", value: last_visit_label, tone: :zinc),
        ProfileMetric.new(label: "Gasto estimado", value: estimated_spend_label, tone: :zinc),
        ProfileMetric.new(label: "Estado", value: primary_status_label, tone: primary_status_tone)
      ]
    end

    def status_chips
      chips = []
      chips << StatusChip.new(label: "Bloqueado", tone: :rose) if customer.blocked?
      chips << StatusChip.new(label: "Seña pendiente", tone: :rose) if pending_deposit?
      chips << StatusChip.new(label: "No-show previo", tone: :rose) if no_show_previous?
      chips << StatusChip.new(label: "Frecuente", tone: :violet) if frequent?
      chips << StatusChip.new(label: "Nuevo", tone: :green) if new_customer?
      chips.presence || [ StatusChip.new(label: "Al día", tone: :green) ]
    end

    def preferences
      tags = []
      tags += appointments.map { |appointment| appointment.service.category.presence }.compact
      tags << preferred_employee&.name
      tags += notes.flat_map { |note| note.body.to_s.scan(/manto|sensible|alergia|baño|bano|corte|deslanado|demora/i) }
      tags.map { |tag| normalize_tag(tag) }.compact.uniq.first(8)
    end

    def source_label
      source = appointments.min_by(&:created_at)&.source
      Appointment.source_label(source || "manual")
    end

    def segments_label
      status_chips.map(&:label).join(" · ")
    end

    def transactional_whatsapp_label
      "Autorizado para gestionar turnos"
    end

    def transactional_email_label
      customer.email.present? ? "Email para confirmaciones y recordatorios" : "Sin email registrado"
    end

    def opportunities
      items = []
      if maintenance_due?
        items << Opportunity.new(
          title: "Le toca mantenimiento",
          body: "Su último turno fue #{last_visit_label}. Podés escribirle para repetir el servicio.",
          url: WhatsApp::CustomerMessageBuilder.new(self).reactivation_url,
          tone: :violet,
          action_label: "Enviar mensaje"
        )
      end

      if pending_deposit?
        items << Opportunity.new(
          title: "Tiene seña pendiente",
          body: "Podés pedir el comprobante o reenviar el enlace seguro.",
          url: WhatsApp::CustomerMessageBuilder.new(self).deposit_request_url,
          tone: :rose,
          action_label: "Pedir comprobante"
        )
      end

      items.presence || [
        Opportunity.new(
          title: "Compatible con seguimiento manual",
          body: "Podés crear un recordatorio interno para volver a contactar más adelante.",
          url: nil,
          tone: :sky,
          action_label: nil
        )
      ]
    end

    def preferred_employee
      employee_counts = appointments.filter_map(&:employee_membership).tally
      employee_counts.max_by { |_employee, count| count }&.first
    end

    def preferred_service
      service_counts = appointments.filter_map(&:service).tally
      service_counts.max_by { |_service, count| count }&.first || business.services.active.order(:sort_order, :name).first
    end

    def pending_deposit_appointment
      appointments.find { |appointment| appointment.pending_deposit? || appointment.pending_deposit_review? || appointment.deposit_rejected? }
    end

    def pending_deposit?
      pending_deposit_appointment.present?
    end

    def frequent?
      total_appointments >= 3
    end

    def new_customer?
      total_appointments <= 1 && customer.created_at > 45.days.ago
    end

    def no_show_previous?
      customer.no_show_count.to_i.positive? || customer.total_cancellations_count.positive? || customer.consecutive_late_cancellations_count.positive?
    end

    private
      def primary_status_tone
        status_chips.first&.tone || :green
      end

      def maintenance_due?
        last_visit.present? && last_visit.starts_at < 30.days.ago && appointments.any?
      end

      def distance_label(time)
        days = ((Time.zone.now - time) / 1.day).floor
        return "Hoy" if days <= 0
        return "Ayer" if days == 1

        "Hace #{days} días"
      end

      def normalize_tag(tag)
        normalized = tag.to_s.strip
        return if normalized.blank?

        case normalized.downcase
        when "manto" then "Cuidado de manto"
        when "sensible" then "Piel sensible"
        when "alergia" then "Alergia"
        when "bano", "baño" then "Baño"
        when "corte" then "Corte"
        when "deslanado" then "Deslanado"
        when "demora" then "Avisar demoras"
        else normalized
        end
      end
  end
end
