module Admin
  class BillingController < BaseController
    def show
      load_billing_context
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
      def load_billing_context
        return unless @business.billing_enabled?

        @subscription = @business.subscription || @business.create_subscription!(external_reference: "business-#{@business.id}-#{SecureRandom.hex(6)}")
        Billing::EnsureCurrentInvoice.call(business: @business)
        @subscription.reload
        @billing_amount = @business.billing_amount
        @current_invoice = @subscription.current_invoice
        @latest_invoice = @subscription.latest_invoice
        @invoices = @business.subscription_invoices.includes(subscription_payment_proofs: { file_attachment: :blob }).recent.limit(36)
      end
  end
end
