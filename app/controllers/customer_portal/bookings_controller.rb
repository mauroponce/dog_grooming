module CustomerPortal
  class BookingsController < BaseController
    RESCHEDULING_WINDOW_DAYS = 8
    RESCHEDULING_HORIZON_DAYS = 60

    before_action :set_appointment

    def show
    end

    def reschedule_availability
      unless @appointment.customer_portal_reschedulable?
        render json: { error: "Este turno ya no se puede reprogramar desde el portal." }, status: :unprocessable_content
        return
      end

      window_start = rescheduling_window_start
      window_end = [ window_start + (RESCHEDULING_WINDOW_DAYS - 1), rescheduling_horizon_end ].min
      dates = (window_start..window_end).to_a
      slots_by_date = dates.index_with { |date| rescheduling_slot_records(date) }
      selected_date = rescheduling_selected_date(dates, slots_by_date)

      render json: {
        windowStart: window_start.iso8601,
        previousWindowStart: rescheduling_previous_window_start(window_start)&.iso8601,
        nextWindowStart: rescheduling_next_window_start(window_start)&.iso8601,
        selectedDate: selected_date.iso8601,
        dates: dates.map { |date| { date: date.iso8601, available: slots_by_date.fetch(date).any? } },
        slots: rescheduling_slot_payloads(slots_by_date.fetch(selected_date))
      }
    rescue Date::Error
      render json: { error: "La fecha seleccionada no es válida." }, status: :unprocessable_content
    end

    def upload_receipt
      replacing = @appointment.deposit_receipt.attached?
      DepositProofs::ReplaceService.new(
        booking: @appointment,
        file: params[:deposit_receipt],
        event_type: replacing ? "customer_replaced_proof" : "customer_uploaded_proof"
      )
        .call
      redirect_to customer_portal_short_booking_path(@business.slug, @appointment.customer_portal_booking_token), notice: "Recibimos tu comprobante. Queda pendiente de revisión."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to customer_portal_booking_path(@business.slug, params[:token]), alert: error.record.errors.full_messages.to_sentence.presence || "No pudimos guardar el comprobante."
    end

    def request_reschedule
      if params[:starts_at].present?
        reschedule_from_portal!
        redirect_to customer_portal_dashboard_path(@business.slug), notice: "Tu turno fue reprogramado."
        return
      end

      create_booking_event!(
        "customer_requested_reschedule",
        "Cliente pidió reprogramar",
        "#{@appointment.customer_name} quiere reprogramar #{@appointment.service.name}."
      )

      redirect_to @appointment.customer_portal_reschedule_whatsapp_url, allow_other_host: true
    rescue Appointments::UnavailableSlot => error
      redirect_to customer_portal_dashboard_path(@business.slug), alert: error.message
    end

    def cancel
      if @appointment.customer_portal_cancellable?
        @appointment.cancel!(by: "customer_portal", reason: params[:cancellation_reason].presence || "Cancelado desde portal de cliente")
        redirect_to customer_portal_dashboard_path(@business.slug), notice: "Tu turno fue cancelado."
      else
        redirect_to customer_portal_booking_path(@business.slug, params[:token]), alert: "Este turno ya no se puede cancelar desde el portal. Contactá al centro por WhatsApp."
      end
    end

    private
      def set_appointment
        @appointment = @business.appointments.includes(:pet).find_by!(customer_portal_token: params[:token])
        raise ActiveRecord::RecordNotFound unless @appointment.business_id == @business.id
      rescue ActiveRecord::RecordNotFound
        redirect_to customer_portal_entry_path(@business.slug), alert: "El enlace de la reserva no es válido."
      end

      def create_booking_event!(event_type, title, body)
        @business.provider_events.create!(
          event_type: event_type,
          title: title,
          body: body,
          metadata: {
            appointment_id: @appointment.id,
            customer_profile_id: @appointment.customer_profile_id,
            action_url: Rails.application.routes.url_helpers.admin_appointment_url(
              @appointment,
              host: app_host,
              protocol: app_protocol
            ),
            whatsapp_url: @appointment.manual_whatsapp_url
          }
        )
      end

      def reschedule_from_portal!
        starts_at = Time.zone.parse(params[:starts_at].to_s)
        raise Appointments::UnavailableSlot, "Seleccioná un horario disponible." if starts_at.blank?

        previous_starts_at = @appointment.starts_at
        Appointments::RescheduleFromCustomerPortal.call(appointment: @appointment, starts_at: starts_at)
        create_booking_event!(
          "customer_rescheduled_booking",
          "Cliente reprogramó un turno",
          "#{@appointment.customer_name} reprogramó #{@appointment.service.name} de #{previous_starts_at.in_time_zone.strftime('%d/%m/%Y %H:%M')} a #{starts_at.in_time_zone.strftime('%d/%m/%Y %H:%M')}."
        )
      rescue ArgumentError, TypeError
        raise Appointments::UnavailableSlot, "Seleccioná un horario disponible."
      end

      def rescheduling_window_start
        requested_start = params[:date_window_start].present? ? Date.parse(params[:date_window_start]) : Time.zone.today
        [ [ requested_start, Time.zone.today ].max, rescheduling_horizon_end ].min
      end

      def rescheduling_horizon_end
        RESCHEDULING_HORIZON_DAYS.days.from_now.to_date
      end

      def rescheduling_selected_date(dates, slots_by_date)
        requested_date = Date.parse(params[:date]) if params[:date].present?
        return requested_date if requested_date.in?(dates)

        dates.find { |date| slots_by_date.fetch(date).any? } || dates.first
      end

      def rescheduling_previous_window_start(window_start)
        return if window_start <= Time.zone.today

        [ window_start - RESCHEDULING_WINDOW_DAYS, Time.zone.today ].max
      end

      def rescheduling_next_window_start(window_start)
        next_start = window_start + RESCHEDULING_WINDOW_DAYS
        next_start if next_start <= rescheduling_horizon_end
      end

      def rescheduling_slot_records(date)
        Availability::Slots.public_records_for(
          business: @business,
          service: @appointment.service,
          date: date,
          excluding_appointment: @appointment
        ).reject { |slot| slot.starts_at.to_i == @appointment.starts_at.to_i }
      end

      def rescheduling_slot_payloads(records)
        records
          .group_by { |slot| slot.starts_at.to_i }
          .values
          .map(&:first)
          .map { |slot| { startsAt: slot.starts_at.iso8601, time: slot.starts_at.strftime("%H:%M") } }
      end

      def app_host
        AppUrl.host
      end

      def app_protocol
        AppUrl.protocol
      end
  end
end
