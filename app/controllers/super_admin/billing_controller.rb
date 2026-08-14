module SuperAdmin
  class BillingController < BaseController
    def show
      load_billing_data
    end

    def update
      account = BillingTransferAccount.current
      account.update!(billing_transfer_account_params)

      redirect_to super_admin_billing_path, notice: "Datos de cobro actualizados."
    rescue ActiveRecord::RecordInvalid => error
      load_billing_data
      @billing_account = account
      flash.now[:alert] = error.record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end

    def approve_payment_proof
      proof = pending_proof!
      Billing::ApprovePayment.call(invoice: proof.subscription_invoice, reviewer: current_user)

      redirect_to super_admin_billing_path, notice: "Pago de #{proof.business.name} aprobado."
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => error
      redirect_to super_admin_billing_path, alert: error.message
    end

    def reject_payment_proof
      proof = pending_proof!
      Billing::RejectPayment.call(
        invoice: proof.subscription_invoice,
        reviewer: current_user,
        reason: params[:reason]
      )

      redirect_to super_admin_billing_path, notice: "Comprobante de #{proof.business.name} rechazado."
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => error
      redirect_to super_admin_billing_path, alert: error.message
    end

    private
      def load_billing_data
        @billing_account = BillingTransferAccount.current
        @pending_payment_proofs = SubscriptionPaymentProof.pending_review
          .includes(:business, :uploaded_by, subscription_invoice: :subscription, file_attachment: :blob)
          .recent
          .limit(50)
      end

      def pending_proof!
        SubscriptionPaymentProof.pending_review.includes(:subscription_invoice).find(params[:proof_id])
      end

      def billing_transfer_account_params
        params.require(:billing_transfer_account).permit(:transfer_alias, :cbu, :account_holder, :tax_id)
      end
  end
end
