module Services
  class ProfilePresenter
    Usage = Struct.new(:reservations_count, :cancellations_count, :no_show_count, :deposits_label, :suggestion, keyword_init: true)

    attr_reader :service, :business

    def initialize(service:, business:)
      @service = service
      @business = business
    end

    def status_chips
      chips = [ service.visibility_label ]
      chips << "Requiere seña" if service.deposit_required?
      chips << "Popular" if service.popular?
      chips << "Completar" if service.incomplete?
      chips
    end

    def professionals_label
      return "Agenda principal" unless business.team_features_available?
      return "Todo el equipo" if service.employee_memberships.blank?

      service.employee_memberships.map(&:name).join(", ")
    end

    def resources_label
      return "Sin recurso requerido" if service.bookable_resources.blank?

      service.bookable_resources.map(&:name).join(", ")
    end

    def balance_label
      cents = [ service.price_cents.to_i - service.expected_deposit_amount_cents.to_i, 0 ].max
      service.price_label_for_cents(cents)
    end

    def payment_link_label
      service.external_payment_link.presence ||
        service.effective_payment_account&.display_name.presence ||
        business.deposit_payment_link.presence ||
        "Usa la cuenta principal del negocio"
    end

    def usage
      range = Time.zone.today.beginning_of_month.beginning_of_day..Time.zone.today.end_of_month.end_of_day
      appointments = service.appointments.where(starts_at: range)
      active = appointments.reject(&:canceled?)
      Usage.new(
        reservations_count: appointments.count,
        cancellations_count: appointments.count(&:canceled?),
        no_show_count: appointments.count { |appointment| appointment.no_show? || appointment.expired? },
        deposits_label: service.price_label_for_cents(active.sum(&:deposit_amount_cents)),
        suggestion: suggestion_for(appointments)
      )
    end

    private
      def suggestion_for(appointments)
        return "Este servicio todavía no tiene reservas este mes. Revisá precio, descripción y visibilidad." if appointments.blank?
        return "Este servicio funciona bien como mantenimiento. Podés sugerirlo a tutores que vinieron hace más de 30 días." if service.category_label.match?(/baño|bano|corte|higiene|manto/i)
        return "Tiene varias cancelaciones. Revisá duración, precio o política de seña." if appointments.count(&:canceled?) >= 2

        "El servicio tiene actividad. Mantené descripción y tags actualizados para mejorar búsqueda."
      end
  end
end
