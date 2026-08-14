module DepositProofs
  class ReplaceService
    def initialize(booking:, file:, event_type: nil)
      @booking = booking
      @file = file
      @event_type = event_type
    end

    def call
      validate_booking!
      validate_file!

      replacing = booking.deposit_receipt.attached?

      booking.transaction do
        archive_current_receipt! if replacing
        attach_new_receipt!
        booking.mark_deposit_submitted!
        notify_admin!(replacement: replacing)
      end

      booking
    end

    private
      attr_reader :booking, :file, :event_type

      def validate_booking!
        raise invalid_record("Este turno no requiere comprobante de seña.") unless booking.manual_payment_required?
        raise invalid_record("Este turno ya no permite subir comprobante.") if closed_booking?
        raise invalid_record("La seña ya fue aprobada. No necesitás subir otro comprobante.") if approved_booking?
      end

      def validate_file!
        raise invalid_record("Subí una imagen o PDF del comprobante.") if file.blank?

        Assets::PrivateAttachmentValidator.validate!(
          file,
          content_types: Appointment::DEPOSIT_RECEIPT_CONTENT_TYPES,
          max_size: Appointment::DEPOSIT_RECEIPT_MAX_SIZE
        )

        extension = File.extname(original_filename).downcase
        return if extension.in?(Appointment::DEPOSIT_RECEIPT_EXTENSIONS)

        raise invalid_record("El comprobante debe ser JPG, JPEG, PNG, WebP o PDF.")
      end

      def archive_current_receipt!
        booking.deposit_receipt_history.attach(booking.deposit_receipt.blob)
        booking.deposit_receipt.detach
      end

      def attach_new_receipt!
        booking.deposit_receipt.attach(
          Storage::UploadAttachable.build(
            file,
            key: Storage::ObjectKeyBuilder.deposit_receipt(booking, filename: original_filename)
          )
        )
      end

      def notify_admin!(replacement:)
        queue_owner_email!(replacement: replacement)
        booking.business.provider_events.create!(
          event_type: event_type.presence || "deposit_receipt_submitted",
          title: "Nuevo comprobante para revisar",
          body: event_body(replacement: replacement),
          metadata: {
            appointment_id: booking.id,
            action_url: booking.deposit_review_url,
            whatsapp_url: booking.manual_whatsapp_url,
            replacement: replacement
          }
        )
      end

      def queue_owner_email!(replacement:)
        BusinessMailer.new_deposit_proof(booking).deliver_later
        booking.notification_deliveries.create!(
          business: booking.business,
          channel: "email",
          recipient: booking.business.owner.email_address,
          template: "deposit_receipt_submitted",
          status: "queued",
          sent_at: Time.current,
          payload: {
            review_url: booking.deposit_review_url,
            replacement: replacement
          }
        )
      end

      def event_body(replacement:)
        action = replacement ? "reemplazó el comprobante" : "subió comprobante"
        "#{booking.customer_name} #{action} de #{booking.formatted_deposit_amount} para #{booking.service.name}, #{booking.customer_starts_at_label}."
      end

      def closed_booking?
        booking.canceled? || booking.expired? || booking.completed? || booking.no_show? || booking.rescheduled?
      end

      def approved_booking?
        booking.confirmed? || booking.deposit_status == "approved"
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
        record = Appointment.new
        record.errors.add(:base, message)
        ActiveRecord::RecordInvalid.new(record)
      end

      def app_host
        AppUrl.host
      end

      def app_protocol
        AppUrl.protocol
      end
  end
end
