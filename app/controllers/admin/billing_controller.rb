module Admin
  class BillingController < BaseController
    def show
      load_billing_context
    end

    def checkout
      load_billing_context
      @current_invoice ||= Billing::EnsureCurrentInvoice.call(business: @business, force: true)
      raise ArgumentError, "No hay una factura pendiente para pagar." unless @current_invoice
      payment = Billing::CreateMercadoPagoCheckout.call(invoice: @current_invoice, host: request.host, protocol: request.protocol)
      redirect_to payment.checkout_url, allow_other_host: true
    rescue ArgumentError, MercadoPago::Client::Error => error
      redirect_to admin_billing_path, alert: error.message
    end

    private
      def load_billing_context
        return unless @business.billing_enabled?

        @subscription = @business.subscription || @business.create_subscription!(external_reference: "business-#{@business.id}-#{SecureRandom.hex(6)}")
        Billing::EnsureCurrentInvoice.call(business: @business)
        @subscription.reload
        @billing_amount = @business.billing_amount
        @current_invoice = @subscription.current_invoice
        @latest_invoice = @subscription.latest_invoice
        @checkout_payment = @current_invoice&.subscription_checkout_payments&.order(created_at: :desc)&.first
        @invoices = @business.subscription_invoices.includes(:subscription_checkout_payments).recent.limit(36)
      end
  end
end
