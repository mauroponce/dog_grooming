module Admin
  class BillingController < BaseController
    def show
      load_billing_context
    end

    def subscribe
      subscription = @business.subscription
      unless subscription&.mercado_pago?
        redirect_to admin_billing_path, alert: "Esta cuenta no usa suscripciones de Mercado Pago."
        return
      end
      account = PlatformMercadoPagoAccount.current
      unless account.connected?
        redirect_to admin_billing_path, alert: "El cobro por Mercado Pago todavía no está disponible. Contactanos."
        return
      end

      subscription.with_lock do
        if subscription.provider_subscription_id.present?
          PlatformMercadoPago::SyncSubscription.call(subscription)
        end
        if subscription.provider_subscription_id.blank? || subscription.provider_status.in?(%w[cancelled canceled])
          payload = PlatformMercadoPago::Client.new(account: account).create_subscription!(business: @business, back_url: admin_billing_url)
          subscription.update!(provider_subscription_id: payload.fetch("id"), provider_status: payload["status"],
            amount_cents: account.monthly_amount_cents, payer_email: current_user.email_address,
            paid_until: nil, raw_payload: payload)
        end
      end

      checkout_url = subscription.raw_payload["init_point"].presence
      if subscription.active?
        redirect_to admin_billing_path, notice: "Tu suscripción ya está activa."
      elsif subscription.provider_status == "authorized"
        redirect_to admin_billing_path, alert: "Mercado Pago todavía no confirmó un cobro vigente. Revisá el medio de pago de tu suscripción e intentá nuevamente."
      elsif subscription.provider_status == "paused"
        redirect_to admin_billing_path, alert: "Tu suscripción está pausada en Mercado Pago. Reactivala desde tu cuenta de Mercado Pago e intentá nuevamente."
      elsif mercado_pago_checkout_url?(checkout_url)
        redirect_to checkout_url, allow_other_host: true
      else
        redirect_to admin_billing_path, alert: "No pudimos abrir el checkout de Mercado Pago. Intentá nuevamente."
      end
    rescue PlatformMercadoPago::Client::Error, KeyError => error
      redirect_to admin_billing_path, alert: error.message
    end

    def upload_payment_proof
      load_billing_context

      unless @current_invoice
        redirect_to admin_billing_path, alert: "No hay una factura abierta para cargar comprobante."
        return
      end

      Billing::UploadPaymentProof.call(
        invoice: @current_invoice,
        file: params[:payment_proof],
        uploaded_by: current_user
      )

      redirect_to admin_billing_path(anchor: "historial"), notice: "Comprobante enviado. Lo revisaremos a la brevedad."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admin_billing_path, alert: error.record.errors.full_messages.to_sentence.presence || error.message
    end

    private
      def mercado_pago_checkout_url?(value)
        uri = URI.parse(value.to_s)
        uri.scheme == "https" && uri.host.to_s.match?(/\A(?:[a-z0-9-]+\.)?mercadopago\.com(?:\.ar)?\z/i)
      rescue URI::InvalidURIError
        false
      end

      def load_billing_context
        return unless @business.billing_enabled?

        @subscription = @business.subscription || @business.create_subscription!(external_reference: "business-#{@business.id}-#{SecureRandom.hex(6)}")
        if @subscription.mercado_pago?
          begin
            PlatformMercadoPago::SyncSubscription.call(@subscription) if @subscription.provider_subscription_id.present?
          rescue PlatformMercadoPago::Client::Error => error
            Rails.logger.warn("No se pudo consultar suscripción de Mercado Pago: #{error.message}")
          end
          @billing_amount = @business.billing_amount
          return
        end
        Billing::EnsureCurrentInvoice.call(business: @business)
        @subscription.reload
        @billing_amount = @business.billing_amount
        @current_invoice = @subscription.current_invoice
        @latest_invoice = @subscription.latest_invoice
        @invoices = @business.subscription_invoices.includes(subscription_payment_proofs: { file_attachment: :blob }).recent.limit(36)
      end
  end
end
