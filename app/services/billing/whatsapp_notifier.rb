module Billing
  class WhatsAppNotifier
    Result = Struct.new(:status, :recipient, :error, keyword_init: true) do
      def sent?
        status == :sent
      end
    end

    def self.call(...)
      new(...).call
    end

    def initialize(invoice:, reminder_type:, client: WhatsApp::EvolutionClient.new)
      @invoice = invoice
      @reminder_type = reminder_type.to_s
      @client = client
    end

    def call
      return skipped_result("Las notificaciones automáticas por WhatsApp están deshabilitadas.") unless WhatsApp::AutomatedNotifications.enabled?
      return skipped_result("WhatsApp no está habilitado.") unless provider_enabled?
      return skipped_result("El negocio no tiene WhatsApp habilitado para notificaciones.") unless business.owner_whatsapp_notifications_ready?

      response = client.send_text(number: business.owner_whatsapp_recipient, text: message)
      return Result.new(status: :sent, recipient: business.owner_whatsapp_recipient) if response[:success]

      Result.new(
        status: :failed,
        recipient: business.owner_whatsapp_recipient,
        error: response[:error].presence || "Evolution API respondió con estado #{response[:status]}"
      )
    rescue StandardError => error
      Result.new(status: :failed, recipient: business.owner_whatsapp_recipient, error: "#{error.class}: #{error.message}")
    end

    private
      attr_reader :invoice, :reminder_type, :client

      delegate :business, to: :invoice

      def provider_enabled?
        ENV.fetch("WHATSAPP_PROVIDER", "").to_s == "evolution" && client.configured?
      end

      def message
        [
          opening,
          "Importe: #{invoice.amount_label}.",
          transfer_details,
          "Referencia: #{invoice.reference_code}.",
          "Subí el comprobante acá: #{billing_url}"
        ].compact_blank.join("\n")
      end

      def opening
        if trial_invoice? && reminder_type == "due_7_days"
          "Hola, el período de prueba de #{business.name} vence en 7 días. Para continuar con Dog Grooming, el pago será de #{invoice.amount_label}."
        elsif trial_invoice? && reminder_type == "due_3_days"
          "Hola, el período de prueba de #{business.name} vence en 3 días. Para continuar con Dog Grooming, el pago será de #{invoice.amount_label}."
        elsif trial_invoice? && reminder_type == "due_today"
          "Hola, terminó el período de prueba de #{business.name}. Para seguir usando Dog Grooming, realizá el pago de #{invoice.amount_label}."
        else
          "Hola, el pago de la suscripción de #{business.name} está pendiente."
        end
      end

      def trial_invoice?
        invoice.subscription.subscribed_at.blank? &&
          business.trial_ends_at.present? &&
          invoice.due_on == business.trial_ends_at.to_date
      end

      def transfer_details
        details = []
        details << "Alias: #{Billing::TransferDetails.alias}" if Billing::TransferDetails.alias.present?
        details << "CBU/CVU: #{Billing::TransferDetails.account}" if Billing::TransferDetails.account.present?
        details << "Titular: #{Billing::TransferDetails.holder}" if Billing::TransferDetails.holder.present?
        details.presence || "Los datos de transferencia están disponibles en el panel."
      end

      def billing_url
        Rails.application.routes.url_helpers.admin_billing_url(host: AppUrl.host, protocol: AppUrl.protocol)
      end

      def skipped_result(error)
        Result.new(status: :skipped, recipient: business.owner_whatsapp_recipient, error: error)
      end
  end
end
