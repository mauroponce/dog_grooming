module SuperAdmin
  class BillingController < BaseController
    def show
      load_billing_data
    end

    def update
      account = BillingTransferAccount.current
      account.validate_account_proof!(account_params[:account_proof])
      account.update!(account_params)
      redirect_to super_admin_billing_path, notice: "Datos bancarios actualizados."
    rescue ActiveRecord::RecordInvalid => error
      load_billing_data
      flash.now[:alert] = error.message
      render :show, status: :unprocessable_entity
    end

    def remove_account_proof
      account = BillingTransferAccount.current
      account.account_proof.purge if account.account_proof.attached?
      redirect_to super_admin_billing_path, notice: "Constancia eliminada."
    end

    def approve_invoice
      invoice = pending_invoice!
      Billing::ApprovePayment.call(invoice: invoice, reviewer: current_user)
      redirect_to super_admin_billing_path, notice: "Pago aprobado."
    rescue StandardError => error
      redirect_to super_admin_billing_path, alert: error.message
    end

    def reject_invoice
      invoice = pending_invoice!
      Billing::RejectPayment.call(invoice: invoice, reviewer: current_user, reason: params[:reason])
      redirect_to super_admin_billing_path, notice: "Pago rechazado."
    rescue StandardError => error
      redirect_to super_admin_billing_path, alert: error.message
    end

    private
      def load_billing_data
        @transfer_account = BillingTransferAccount.current
        @pending_invoices = SubscriptionInvoice.pending_review.includes(:business, :subscription, subscription_payment_proofs: :uploaded_by).recent.limit(50)
      end

      def account_params
        params.require(:billing_transfer_account).permit(:transfer_alias, :cbu, :account_holder, :tax_id, :account_proof)
      end

      def pending_invoice!
        SubscriptionInvoice.pending_review.find(params.require(:invoice_id))
      end
  end
end
