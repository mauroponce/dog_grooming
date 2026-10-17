module Billing
  class CreateMercadoPagoCheckout
    def self.call(...) = new(...).call

    def initialize(invoice:, host: AppUrl.host, protocol: AppUrl.protocol)
      @invoice = invoice
      @host = host
      @protocol = protocol.to_s.delete_suffix("://")
    end

    def call
      raise ArgumentError, "La factura ya fue pagada." if invoice.paid?
      raise ArgumentError, "Conectá la cuenta de Mercado Pago de Cita.pet antes de cobrar." unless connection.connected?

      invoice.with_lock do
        return active_payment if active_payment

        payment = invoice.subscription_checkout_payments.create!(
          business: invoice.business,
          amount_cents: invoice.amount_cents,
          currency: "ARS",
          external_reference: "cita-pet-invoice-#{invoice.id}-#{SecureRandom.urlsafe_base64(12)}",
          expires_at: expiration_time
        )
        preference = MercadoPago::Client.for_connection(connection).create_preference!(preference_payload(payment))
        payment.update!(preference_id: preference["id"], init_point: preference["init_point"], sandbox_init_point: preference["sandbox_init_point"], raw_payload: preference)
        payment
      end
    end

    private
      attr_reader :invoice, :host, :protocol

      def connection
        @connection ||= BillingMercadoPagoConnection.current
      end

      def active_payment
        invoice.subscription_checkout_payments.order(created_at: :desc).find(&:active?)
      end

      def expiration_time
        (invoice.subscription.grace_ends_on || invoice.due_on + 15.days).end_of_day
      end

      def preference_payload(payment)
        {
          items: [ { id: payment.external_reference, title: "Suscripción Cita.pet", description: "#{invoice.business.name} · #{invoice.reference_code}", quantity: 1, currency_id: "ARS", unit_price: invoice.amount_cents / 100.0 } ],
          external_reference: payment.external_reference,
          metadata: { subscription_invoice_id: invoice.id, business_id: invoice.business_id, external_reference: payment.external_reference },
          payer: { email: invoice.business.owner.email_address },
          back_urls: back_urls,
          auto_return: "approved",
          notification_url: notification_url(payment),
          expires: true,
          expiration_date_from: Time.current.iso8601,
          expiration_date_to: payment.expires_at.iso8601
        }
      end

      def back_urls
        path = Rails.application.routes.url_helpers.admin_billing_url(host: host, protocol: protocol)
        { success: path, pending: path, failure: path }
      end

      def notification_url(payment)
        return if host.include?("localhost") || host.include?("127.0.0.1")

        Rails.application.routes.url_helpers.webhooks_mercado_pago_url(reference: payment.external_reference, host: host, protocol: protocol)
      end
  end
end
