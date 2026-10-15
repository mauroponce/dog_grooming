module SuperAdmin
  class BillingController < BaseController
    def show
      load_billing_data
    end

    private
      def load_billing_data
        @mercado_pago_connection = BillingMercadoPagoConnection.current
        @pending_checkout_payments = SubscriptionCheckoutPayment.pending.includes(:business, :subscription_invoice).order(created_at: :desc).limit(50)
      end
  end
end
