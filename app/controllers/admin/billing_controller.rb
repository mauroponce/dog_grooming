module Admin
  class BillingController < BaseController
    def show
      load_billing_context
    end

    def select_plan
      load_billing_context
      raise ArgumentError, "No se puede cambiar el plan mientras hay un comprobante en revisión." if @current_invoice&.pending_review?
      plan = params.require(:subscription).fetch(:plan_selected)
      raise ArgumentError, "Elegí un plan válido." unless Subscription::PLANS.key?(plan)

      @subscription.update!(plan_selected: plan, amount_cents: Subscription::PLANS.fetch(plan).fetch(:amount_cents))
      @current_invoice&.update!(amount_cents: @subscription.amount_cents, plan_selected: plan) unless @current_invoice&.paid?
      redirect_to admin_billing_path, notice: "Plan seleccionado. Ya podés transferir y subir el comprobante."
    rescue ArgumentError, ActionController::ParameterMissing => error
      redirect_to admin_billing_path, alert: error.message
    end

    def upload_proof
      load_billing_context
      invoice = @current_invoice || Billing::EnsureCurrentInvoice.call(business: @business, force: true)
      raise ArgumentError, "No hay una factura pendiente para pagar." unless invoice
      raise ArgumentError, "Primero configurá el plan que querés usar." unless @subscription.plan_selected.present?

      Billing::UploadPaymentProof.call(invoice: invoice, file: params[:file], uploaded_by: current_user)
      redirect_to admin_billing_path, notice: "Recibimos tu comprobante. Te avisaremos cuando sea aprobado."
    rescue ArgumentError, ActiveRecord::RecordInvalid => error
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
        @transfer_account = BillingTransferAccount.current
        @invoices = @business.subscription_invoices.includes(:subscription_payment_proofs).recent.limit(36)
      end
  end
end
