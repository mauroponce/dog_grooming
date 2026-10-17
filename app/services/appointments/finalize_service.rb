module Appointments
  class FinalizeService
    class Error < StandardError; end

    OUTCOMES = %w[completed no_show cancelled rescheduled].freeze
    PHOTO_LIMIT = 3

    def initialize(appointment:, actor:, params:)
      @appointment = appointment
      @actor = actor
      @params = params.to_h.with_indifferent_access
    end

    def call
      raise Error, "El turno no tiene un cliente asociado." if appointment.customer_profile.blank?

      appointment.business.with_lock do
        appointment.reload
        return appointment if appointment.status == terminal_status_for_outcome
        raise Error, "Este turno ya está cerrado." if appointment.terminal_status?
        raise Error, "El turno todavía no se puede finalizar." if outcome == "completed" && !appointment.finalizable?
        validate_payload!

        case outcome
        when "completed"
          complete_appointment!
        when "no_show"
          mark_no_show!
        when "cancelled"
          cancel_appointment!
        when "rescheduled"
          mark_rescheduled!
        end
      end

      appointment
    end

    # Adding information after completion must never repeat completion side effects.
    def append_treatment
      appointment.business.with_lock do
        appointment.reload
        raise Error, "Primero finalizá el turno." unless appointment.completed?
        raise Error, "El turno no tiene un cliente asociado." if appointment.customer_profile.blank?
        validate_payload!
        create_note!("post_appointment")
        attach_post_appointment_photos!
      end
      appointment
    end

    private
      attr_reader :appointment, :actor, :params

      def terminal_status_for_outcome
        outcome == "cancelled" ? "canceled" : outcome
      end

      def outcome
        @outcome ||= params[:outcome].presence_in(OUTCOMES) || "completed"
      end

      def note_body
        @note_body ||= params[:body].to_s.strip
      end

      def cancellation_reason
        params[:cancellation_reason].to_s.strip.presence || note_body.presence
      end

      def photos
        @photos ||= Array(params[:photos]).reject do |photo|
          photo.blank? || (photo.respond_to?(:size) && photo.size.to_i.zero?)
        end
      end

      def selected_employee_membership
        return appointment.employee_membership if params[:employee_membership_id].blank?

        appointment.business.employee_memberships.available_for_booking.find_by(id: params[:employee_membership_id]) ||
          raise(Error, "La profesional seleccionada no pertenece al negocio.")
      end

      def follow_up_at
        @follow_up_at ||= begin
          case params[:follow_up_option].to_s
          when "21_days" then 21.days.from_now
          when "30_days" then 30.days.from_now
          when "custom" then custom_follow_up_at
          end
        end
      end

      def custom_follow_up_at
        return if params[:follow_up_date].blank?

        Time.zone.parse("#{params[:follow_up_date]} 09:00")
      rescue ArgumentError
        raise Error, "La fecha de seguimiento no es válida."
      end

      def validate_payload!
        raise Error, "La nota no puede superar 10.000 caracteres." if note_body.length > 10_000

        if photos.any?
          existing_count = appointment.booking_attachments.post_appointment_photos.count
          if existing_count + photos.size > PHOTO_LIMIT
            raise Error, "Podés guardar hasta #{PHOTO_LIMIT} fotos por turno."
          end

          photos.each { |photo| BookingAttachment.validate_photo_upload!(photo) }
        end
      rescue ActiveRecord::RecordInvalid => error
        raise Error, error.record.errors.full_messages.to_sentence
      end

      def complete_appointment!
        attrs = {
          status: :completed,
          completed_at: Time.current,
          completed_by: actor
        }
        attrs[:employee_membership] = selected_employee_membership if appointment.employee_membership.blank? && selected_employee_membership.present?

        appointment.update!(attrs)
        create_note!("post_appointment")
        attach_post_appointment_photos!
        create_follow_up_reminder!
        consume_customer_pack_session!
        create_provider_event!(
          event_type: "appointment_completed",
          title: "Turno guardado en historial",
          body: "Atención finalizada y guardada en el historial."
        )
      end

      def mark_no_show!
        appointment.update!(
          status: :no_show,
          completed_at: Time.current,
          no_show_at: Time.current,
          completed_by: actor
        )
        create_note!("no_show")
        appointment.customer_profile.register_no_show!(appointment)
        create_provider_event!(
          event_type: "appointment_no_show",
          title: "Turno marcado como no asistió",
          body: "#{appointment.customer_name} no asistió al turno de #{appointment.service.name}."
        )
      end

      def cancel_appointment!
        appointment.cancel!(by: actor, reason: cancellation_reason)
        create_note!("cancellation")
      end

      def mark_rescheduled!
        appointment.update!(
          status: :rescheduled,
          canceled_at: Time.current,
          canceled_by: actor.email_address,
          canceled_by_user: actor,
          cancellation_reason: cancellation_reason.presence || "Reprogramado desde el panel"
        )
        create_note!("reschedule")
        create_provider_event!(
          event_type: "appointment_rescheduled",
          title: "Turno marcado como reprogramado",
          body: "#{appointment.customer_name} requiere un nuevo horario para #{appointment.service.name}."
        )
      end

      def create_note!(note_type)
        return if note_body.blank? && cancellation_reason.blank? && follow_up_at.blank?

        appointment.booking_notes.create!(
          business: appointment.business,
          customer_profile: appointment.customer_profile,
          employee_membership: appointment.employee_membership,
          created_by: actor,
          note_type: note_type,
          body: note_body.presence || cancellation_reason,
          follow_up_at: note_type == "post_appointment" ? follow_up_at : nil
        )
      end

      def attach_post_appointment_photos!
        photos.each do |photo|
          attachment = appointment.booking_attachments.create!(
            business: appointment.business,
            customer_profile: appointment.customer_profile,
            uploaded_by: actor,
            attachment_type: "post_appointment_photo",
            visibility: "internal"
          )
          attachment.file.attach(
            Storage::UploadAttachable.build(
              photo,
              key: Storage::ObjectKeyBuilder.post_appointment_photo(appointment, filename: uploaded_filename(photo))
            )
          )
        end
      end

      def create_follow_up_reminder!
        return if follow_up_at.blank?

        appointment.business.customer_reminders.create!(
          customer_profile: appointment.customer_profile,
          service: appointment.service,
          appointment: appointment,
          assigned_to: actor,
          reminder_type: "service_follow_up",
          remind_at: follow_up_at,
          body: "Seguimiento de #{appointment.service.name}: #{note_body.presence || "revisar evolución y próxima reserva"}"
        )
      end

      def consume_customer_pack_session!
        pack = appointment.business.customer_packs.active.includes(:service_pack).where(customer_profile: appointment.customer_profile).find do |customer_pack|
          customer_pack.compatible_with?(appointment.service)
        end
        return if pack.blank?

        pack.consume_session!(appointment: appointment, actor: actor, notes: "Consumida al finalizar turno ##{appointment.id}")
      rescue ActiveRecord::RecordInvalid, RuntimeError => error
        Rails.logger.warn("CustomerPack consumption skipped for appointment #{appointment.id}: #{error.class} #{error.message}")
      end

      def create_provider_event!(event_type:, title:, body:)
        appointment.business.provider_events.create!(
          user: actor,
          event_type: event_type,
          title: title,
          body: body,
          metadata: {
            appointment_id: appointment.id,
            customer_profile_id: appointment.customer_profile_id,
            service_id: appointment.service_id
          }
        )
      end

      def uploaded_filename(upload)
        return upload.original_filename if upload.respond_to?(:original_filename)

        upload.respond_to?(:path) ? File.basename(upload.path) : "foto-post-turno"
      end
  end
end
