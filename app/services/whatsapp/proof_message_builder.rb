module WhatsApp
  class ProofMessageBuilder
    Template = Struct.new(:key, :title, :description, :url, keyword_init: true)

    def initialize(appointment)
      @appointment = appointment
    end

    def templates
      [
        Template.new(key: :confirmed, title: "Avisar turno confirmado", description: "Incluye servicio, fecha y horario.", url: confirmed_url),
        Template.new(key: :clearer_receipt, title: "Pedir comprobante más claro", description: "Para capturas ilegibles o incompletas.", url: clearer_receipt_url),
        Template.new(key: :rejected, title: "Avisar comprobante rechazado", description: "Incluye enlace para subir uno nuevo.", url: rejected_url),
        Template.new(key: :deposit_data, title: "Reenviar datos de seña", description: "Alias/CBU/CVU o enlace externo configurado.", url: deposit_data_url),
        Template.new(key: :secure_link, title: "Enviar enlace seguro", description: "Link de la reserva para confirmar o cancelar.", url: secure_booking_url)
      ]
    end

    def confirmed_url
      template_url("booking_confirmation")
    end

    def clearer_receipt_url
      template_url("proof_request")
    end

    def rejected_url(reason: nil)
      template_url("proof_rejected")
    end

    def deposit_data_url
      template_url("deposit_request")
    end

    def secure_booking_url
      template_url("public_booking_link")
    end

    private
      attr_reader :appointment

      def template_url(key)
        WhatsApp::MessageBuilder.new(
          business: appointment.business,
          template_key: key,
          booking: appointment,
          customer: appointment.customer_profile,
          service: appointment.service,
          professional: appointment.employee_membership
        ).url(phone: appointment.customer_phone)
      end
  end
end
