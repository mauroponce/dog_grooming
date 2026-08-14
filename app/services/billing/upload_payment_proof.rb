module Billing
  class UploadPaymentProof
    def self.call(...)
      new(...).call
    end

    def initialize(invoice:, file:, uploaded_by:)
      @invoice = invoice
      @file = file
      @uploaded_by = uploaded_by
    end

    def call
      validate_file!
      replacing = invoice.current_proof&.pending_review? || invoice.current_proof&.rejected?

      proof = nil
      invoice.transaction do
        replace_current_proof! if replacing
        proof = invoice.subscription_payment_proofs.create!(
          business: invoice.business,
          uploaded_by: uploaded_by,
          uploaded_at: Time.current,
          status: "pending_review"
        )
        attach_file!(proof)
        invoice.update!(status: "pending_review")
        invoice.subscription.update!(status: "pending_review")
        create_review_task!(proof)
      end

      BillingMailer.payment_proof_received(proof).deliver_later
      proof
    end

    private
      attr_reader :invoice, :file, :uploaded_by

      def validate_file!
        raise invalid_record("Subí una imagen o PDF del comprobante.") if file.blank?

        Assets::PrivateAttachmentValidator.validate!(
          file,
          content_types: SubscriptionPaymentProof::CONTENT_TYPES,
          max_size: SubscriptionPaymentProof::MAX_SIZE
        )

        extension = File.extname(original_filename).downcase
        return if extension.in?(SubscriptionPaymentProof::EXTENSIONS)

        raise invalid_record("El comprobante debe ser JPG, JPEG, PNG, WebP o PDF.")
      end

      def replace_current_proof!
        invoice.current_proof&.update!(status: "replaced", replaced_at: Time.current)
      end

      def attach_file!(proof)
        proof.file.attach(
          Storage::UploadAttachable.build(
            file,
            key: Storage::ObjectKeyBuilder.subscription_payment_proof(proof, filename: original_filename)
          )
        )
      end

      def create_review_task!(proof)
        SuperAdminTask.find_or_create_by!(
          business: invoice.business,
          task_type: "review_subscription_payment",
          record: proof
        ) do |task|
          task.title = "Revisar pago de #{invoice.business.name}"
          task.body = "#{invoice.business.name} subió comprobante por #{invoice.amount_label}."
          task.due_at = Time.current
        end
      end

      def original_filename
        if file.respond_to?(:original_filename)
          file.original_filename.to_s
        elsif file.respond_to?(:path)
          File.basename(file.path)
        else
          "comprobante"
        end
      end

      def invalid_record(message)
        record = SubscriptionPaymentProof.new
        record.errors.add(:base, message)
        ActiveRecord::RecordInvalid.new(record)
      end
  end
end
