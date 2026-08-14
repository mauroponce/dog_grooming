module WhatsApp
  class CustomerMessageBuilder
    Template = Struct.new(:key, :title, :description, :url, keyword_init: true)

    def initialize(profile)
      @profile = profile
      @customer = profile.customer
      @business = profile.business
    end

    def templates
      [
        Template.new(key: :reminder, title: "Recordar próximo turno", description: "Incluye fecha, hora y servicio.", url: reminder_url),
        Template.new(key: :booking_link, title: "Enviar link de reserva", description: "Para que el cliente reserve desde la web.", url: booking_link_url),
        Template.new(key: :gap_offer, title: "Ofrecer hueco libre", description: "Mensaje manual para llenar agenda rápido.", url: gap_offer_url),
        Template.new(key: :reactivation, title: "Reactivar cliente", description: "Para clientes sin visita reciente.", url: reactivation_url),
        Template.new(key: :deposit_request, title: "Pedir comprobante", description: "Si tiene una seña pendiente.", url: deposit_request_url),
        Template.new(key: :reschedule, title: "Avisar cambio de turno", description: "Cancelación o reprogramación manual.", url: reschedule_url)
      ]
    end

    def general_url
      template_url("customer_reactivation")
    end

    def reminder_url
      appointment = profile.next_appointment
      template_url("appointment_reminder", booking: appointment, service: appointment&.service)
    end

    def booking_link_url
      template_url("public_booking_link")
    end

    def gap_offer_url
      template_url("gap_offer", service: profile.preferred_service)
    end

    def reactivation_url
      template_url("customer_reactivation")
    end

    def deposit_request_url
      appointment = profile.pending_deposit_appointment
      return booking_link_url unless appointment

      template_url("deposit_request", booking: appointment, service: appointment.service)
    end

    def reschedule_url
      template_url("booking_reschedule", booking: profile.next_appointment, service: profile.next_appointment&.service)
    end

    private
      attr_reader :profile, :customer, :business

      def template_url(key, booking: nil, service: nil, gap: nil)
        WhatsApp::MessageBuilder.new(
          business: business,
          template_key: key,
          booking: booking,
          customer: customer,
          service: service,
          gap: gap
        ).url(phone: customer.phone)
      end
  end
end
