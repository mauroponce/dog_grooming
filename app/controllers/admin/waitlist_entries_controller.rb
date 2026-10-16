module Admin
  class WaitlistEntriesController < BaseController
    def create
      entry = @business.waitlist_entries.create!(waitlist_entry_attributes.merge(source: "admin", status: "waiting"))

      render json: waitlist_entry_payload(entry.reload), status: :created
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, Date::Error, ArgumentError => error
      render json: { errors: error_messages_for(error) }, status: :unprocessable_entity
    end

    def update
      entry = waitlist_entry
      entry.update!(waitlist_entry_attributes)

      render json: waitlist_entry_payload(entry.reload)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, Date::Error, ArgumentError => error
      render json: { errors: error_messages_for(error) }, status: :unprocessable_entity
    end

    def destroy
      waitlist_entry.dismiss!

      render json: { id: params[:id].to_s, deleted: true }
    end

    private
      def waitlist_entry
        @waitlist_entry ||= policy_scope(WaitlistEntry).find(params[:id])
      end

      def waitlist_entry_params
        params.require(:waitlist_entry).permit(
          :service_id,
          :employee_membership_id,
          :customer_profile_id,
          :client_name,
          :client_phone,
          :email,
          :desired_date,
          :notes,
          preferred_time_windows: [ :period, :label, :start_time, :end_time ]
        )
      end

      def waitlist_entry_attributes
        attrs = waitlist_entry_params.to_h.with_indifferent_access
        attrs[:desired_date] = Date.parse(attrs[:desired_date].to_s) if attrs[:desired_date].present?
        attrs[:preferred_time_windows] = normalized_time_windows(attrs[:preferred_time_windows])
        attrs[:employee_membership_id] = nil if attrs[:employee_membership_id].blank?
        assign_customer_attributes!(attrs)
        validate_contact_details!(attrs)
        attrs
      end

      def assign_customer_attributes!(attrs)
        return if attrs[:customer_profile_id].blank?

        customer = @business.customer_profiles.find(attrs[:customer_profile_id])
        attrs[:client_name] = customer.name.presence || attrs[:client_name]
        attrs[:client_phone] = customer.phone.presence || attrs[:client_phone]
        attrs[:email] = customer.email.presence || attrs[:email]
      end

      def normalized_time_windows(raw_windows)
        Array(raw_windows).filter_map { |window| WaitlistEntry.normalize_time_window(window) }.presence ||
          [ WaitlistEntry.normalize_time_window("any") ]
      end

      def validate_contact_details!(attrs)
        raise ArgumentError, "Completá el teléfono del cliente." if attrs[:client_phone].blank?
        raise ArgumentError, "Completá el email del cliente." if attrs[:email].blank?
        raise ArgumentError, "Ingresá un email válido." unless attrs[:email].to_s.match?(URI::MailTo::EMAIL_REGEXP)
      end

      def waitlist_entry_payload(entry)
        service = entry.service
        employee = entry.employee_membership

        {
          id: entry.id.to_s,
          status: entry.status,
          statusLabel: waitlist_status_label(entry.status),
          clientName: entry.client_name,
          clientPhone: entry.client_phone,
          email: entry.email,
          customerProfileId: entry.customer_profile_id&.to_s,
          customerInitials: initials_for(entry.customer_profile&.name.presence || entry.client_name),
          serviceId: service.id.to_s,
          serviceName: service.name,
          serviceDuration: service.duration_minutes,
          servicePrice: service.price_cents / 100,
          employeeId: employee&.id&.to_s,
          employeeName: employee&.display_name,
          desiredDate: entry.desired_date.iso8601,
          desiredDateLabel: CustomerDateFormatter.date_label(entry.desired_date),
          preferredTimeWindows: entry.preferred_time_windows,
          preferredTimeLabels: entry.preferred_time_window_labels,
          notes: entry.notes,
          createdAt: entry.created_at.iso8601,
          createdAtLabel: helpers.time_ago_in_words(entry.created_at) + " atrás",
          updateUrl: admin_waitlist_entry_path(entry, format: :json),
          destroyUrl: admin_waitlist_entry_path(entry, format: :json)
        }
      end

      def waitlist_status_label(status)
        {
          "waiting" => "En espera",
          "offered" => "Disponible para reservar",
          "booked" => "Reservada",
          "dismissed" => "Eliminada",
          "expired" => "Caducada"
        }.fetch(status.to_s, status.to_s)
      end

      def initials_for(value)
        value.to_s.split(/\s+/).filter_map { |part| part[0] }.first(2).join.upcase.presence || "HT"
      end

      def error_messages_for(error)
        if error.respond_to?(:record) && error.record&.errors&.any?
          error.record.errors.full_messages
        else
          [ error.message.presence || "No se pudo guardar la lista de espera." ]
        end
      end
  end
end
