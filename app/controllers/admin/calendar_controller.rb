module Admin
  class CalendarController < BaseController
    def show
      scoped_appointments = policy_scope(@business.appointments)
      @calendar_date = selected_calendar_date(scoped_appointments)
      presenter = Admin::CalendarPresenter.new(
        business: @business,
        appointments_scope: scoped_appointments,
        current_user: current_user,
        params: { calendar_date: @calendar_date.iso8601 }
      )

      @calendar_employees = calendar_employees(presenter)
      @calendar_employee_ids = @calendar_employees.map { |employee| employee.fetch(:id) }
      @calendar_services = calendar_services
      @calendar_appointments = calendar_appointments(scoped_appointments)
      @calendar_blocks = calendar_blocks
      @calendar_waitlist_entries = policy(@business).waitlist? ? calendar_waitlist_entries : []
      @calendar_notifications = calendar_notifications
    end

    private
      def selected_calendar_date(scoped_appointments)
        parse_date(params[:date]) || appointment_date(scoped_appointments) || Time.zone.today
      end

      def parse_date(value)
        return if value.blank?

        Date.iso8601(value.to_s)
      rescue Date::Error
        nil
      end

      def appointment_date(scoped_appointments)
        return if params[:t].blank?

        scoped_appointments.where(short_uuid: params[:t]).pick(:starts_at)&.to_date
      end

      def calendar_range
        @calendar_range ||= begin
          grid_start = @calendar_date.beginning_of_month.beginning_of_week(:monday)
          grid_end = @calendar_date.end_of_month.end_of_week(:monday)
          grid_start.beginning_of_day..grid_end.end_of_day
        end
      end

      def calendar_employees(presenter)
        employees = presenter.available_employees
        employees += policy_scope(@business.appointments)
          .where.not(status: Appointment.statuses[:canceled])
          .where(starts_at: calendar_range)
          .includes(employee_membership: [ :profile_photo_attachment, { user: { profile_photo_attachment: :blob } } ])
          .map(&:employee_membership)
          .compact
        employees = employees.uniq(&:id)
        employees = @business.employee_memberships.available_for_booking.with_attached_profile_photo.includes(user: { profile_photo_attachment: :blob }).ordered.limit(6).to_a if employees.blank?

        if employees.blank?
          [ center_employee_payload ]
        else
          employees.map.with_index { |employee, index| employee_payload(employee, index) }
        end
      end

      def center_employee_payload
        {
          id: "center",
          name: @business.name,
          role: "Agenda del centro",
          avatar: @business.initials,
          color: "#ffded4"
        }
      end

      def employee_payload(employee, index)
        colors = %w[#ffded4 #f59e0b #ec4899 #14b8a6 #2563eb #22c55e #ef4444]
        color = employee.calendar_color.presence || colors.fetch(index % colors.size)
        profile_photo = employee.effective_profile_photo
        {
          id: employee.id.to_s,
          name: employee.display_name,
          role: employee.specialty_label,
          avatar: employee.initials,
          color: color,
          photoUrl: profile_photo.attached? ? url_for(profile_photo) : nil
        }
      end

      def calendar_services
        employee_ids = @calendar_employee_ids.presence || [ "center" ]
        services = @business.services.active.includes(:service_category, :employee_memberships, service_variants: :pet_size_band).order(:category, :sort_order, :name).to_a
        services.map do |service|
          assigned_ids = service.employee_memberships.map { |employee| employee.id.to_s }
          {
            id: service.id.to_s,
            name: service.name,
            category: service.category_label,
            duration: service.duration_minutes,
            price: service.price_cents / 100,
            variants: service.tiered_pricing? ? service.service_variants.active.ordered.map { |variant|
              {
                id: variant.id.to_s,
                name: variant.display_name,
                duration: variant.duration_minutes,
                price: variant.price_cents / 100
              }
            } : [],
            employees: assigned_ids.presence || employee_ids
          }
        end
      end

      def calendar_appointments(scoped_appointments)
        scoped_appointments
          .where.not(status: Appointment.statuses[:canceled])
          .includes(:appointment_payment, :branch, :bookable_resource, :employee_membership, :customer_profile, :pet, deposit_receipt_attachment: :blob, service: [ :payment_account, { service_variants: :pet_size_band } ], appointment_addons: :service)
          .where(starts_at: calendar_range)
          .order(:starts_at)
          .map { |appointment| appointment_payload(appointment) }
      end

      def appointment_payload(appointment)
        customer_profile = appointment.customer_profile
        status = calendar_status(appointment)
        appointment_services = [
          { id: appointment.service_id.to_s, name: appointment.service.name, duration: appointment.service_variant_duration_minutes || appointment.service.duration_minutes, price: (appointment.service_variant_price_cents || appointment.service.price_cents) / 100 }
        ] + appointment.appointment_addons.map { |addon| { id: addon.service_id.to_s, name: addon.service.name, duration: addon.service.duration_minutes, price: addon.service.price_cents / 100 } }
        {
          id: appointment.short_uuid,
          employeeId: appointment.employee_membership_id.present? ? appointment.employee_membership_id.to_s : fallback_employee_id,
          startsAt: appointment.starts_at.iso8601,
          dateISO: appointment.starts_at.to_date.iso8601,
          start: time_label(appointment.starts_at),
          finish: time_label(appointment.ends_at),
          duration: [ ((appointment.ends_at - appointment.starts_at) / 60).round, 15 ].max,
          client: appointment.pet&.name || appointment.customer_name,
          ownerName: appointment.customer_name,
          petId: appointment.pet_id&.to_s,
          petName: appointment.pet&.name,
          petBreed: appointment.pet&.breed,
          petSex: appointment.pet&.sex_label,
          petNotes: appointment.pet&.notes,
          phone: appointment.customer_phone,
          customerEmail: appointment.customer_calendar_email,
          customerProfileId: appointment.customer_profile_id&.to_s,
          customerProfileUrl: appointment.customer_profile_id.present? ? edit_admin_customer_profile_path(appointment.customer_profile_id, return_to: admin_calendar_path(date: @calendar_date.iso8601, t: appointment.short_uuid)) : nil,
          customerProfilePanelUrl: appointment.customer_profile_id.present? ? panel_admin_customer_profile_path(appointment.customer_profile_id, format: :json) : nil,
          customerPortalUrl: customer_portal_url_for(customer_profile),
          customerCreatedAt: customer_profile&.created_at&.to_date&.iso8601,
          customerSummary: customer_summary_payload_for(customer_profile),
          service: appointment.service.name,
          services: appointment_services,
          price: appointment_services.sum { |service| service[:price] },
          depositAmount: appointment.deposit_amount_cents.to_i / 100,
          depositPaidAt: appointment.deposit_paid_at&.iso8601,
          depositPaymentMethod: appointment.deposit_payment_method_label,
          remainingBalance: appointment.remaining_balance_cents.to_i / 100,
          remainingBalancePaidAt: appointment.remaining_balance_paid_at&.iso8601,
          remainingBalancePaidAmount: appointment.remaining_balance_paid_cents.to_i / 100,
          remainingBalancePaymentMethod: appointment.remaining_balance_payment_method_label,
          status: status,
          statusLabel: admin_appointment_status_label(status),
          color: appointment_color(appointment, status:),
          url: admin_appointment_path(appointment)
        }.merge(appointment_detail_payload(appointment)).tap do |payload|
          actions_available = status != "completed"
          payload[:notesUrl] = update_notes_admin_appointment_path(appointment, format: :json) if policy(appointment).update?
          if actions_available && appointment.starts_at.future? && appointment.service.tiered_pricing? && policy(appointment).update?
            payload[:serviceVariantId] = appointment.service_variant_id&.to_s
            payload[:serviceVariantName] = appointment.service_variant_name
            payload[:serviceVariantOptions] = appointment.service.service_variants.active.ordered.map do |variant|
              { id: variant.id.to_s, label: variant.display_name, price: variant.price_cents / 100, duration: variant.duration_minutes }
            end
            payload[:updateServiceVariantUrl] = update_service_variant_admin_appointment_path(appointment, format: :json)
          end
          payload[:destroyUrl] = admin_destroy_appointment_path(appointment, format: :json) if actions_available && policy(appointment).destroy?
          payload[:approveDepositUrl] = approve_deposit_admin_appointment_path(appointment, format: :json) if actions_available && appointment.pending_deposit_review? && policy(appointment).approve_deposit?
          payload[:rejectDepositUrl] = reject_deposit_admin_appointment_path(appointment, format: :json) if actions_available && appointment.pending_deposit_review? && policy(appointment).reject_deposit?
          if actions_available && professional_change_available?(appointment)
            payload[:availableProfessionalsUrl] = available_professionals_admin_appointment_path(appointment, format: :json)
            payload[:changeProfessionalUrl] = change_professional_admin_appointment_path(appointment, format: :json)
          end
          payload[:cancelUrl] = cancel_admin_appointment_path(appointment, format: :json) if actions_available && !appointment.pending_deposit_review? && policy(appointment).cancel? && appointment.starts_at.future?
          payload[:markRemainingBalancePaidUrl] = mark_remaining_balance_paid_admin_appointment_path(appointment, format: :json) if actions_available && policy(appointment).update? && appointment.remaining_balance_payable?
        end
      end

      def fallback_employee_id
        @calendar_employee_ids.first || "center"
      end

      def calendar_status(appointment)
        return "completed" if appointment.confirmed? && appointment.ends_at <= Time.current

        appointment.status
      end

      def appointment_color(appointment, status: calendar_status(appointment))
        return "#f4f4f5" if appointment.canceled? || appointment.no_show? || appointment.expired?
        return "#fef3c7" if appointment.pending_deposit_review? || appointment.deposit_status == "submitted"
        return "#ffe4e6" if appointment.pending_deposit? || appointment.deposit_rejected? || appointment.deposit_status.in?(%w[pending rejected failed])
        return "#ffded4" if status == "completed"
        return "#ffded4" if appointment.pending? || (appointment.confirmed? && appointment.starts_at < Time.current)

        "#d1fae5"
      end

      def calendar_blocks
        blocks = AvailabilityBlock.occurrences_for(
          business: @business,
          starts_at: calendar_range.begin,
          ends_at: calendar_range.end
        )
        if current_user.employee?
          membership = current_employee_membership
          blocks = blocks.select { |block| block.employee_membership_id.blank? || block.employee_membership_id == membership.id } unless membership&.can?("can_view_all_bookings")
        end
        blocks.map do |block|
          {
            id: block.id.to_s,
            seriesId: block.series_id.to_s,
            employeeId: block.employee_membership_id&.to_s,
            startsAt: block.starts_at.iso8601,
            dateISO: block.starts_at.to_date.iso8601,
            start: time_label(block.starts_at),
            finish: time_label(block.ends_at),
            duration: [ ((block.ends_at - block.starts_at) / 60).round, 15 ].max,
            reason: block.reason.presence || AvailabilityBlock::BLOCK_TYPES.fetch(block.block_type, "Bloqueo"),
            description: block.description,
            recurrence: block.recurrence,
            recurrenceLabel: AvailabilityBlock::RECURRENCES.fetch(block.recurrence, "No se repite"),
            onlineBookingAllowed: block.online_booking_allowed,
            color: "#e5e7eb"
          }
        end
      end

      def calendar_waitlist_entries
        policy_scope(WaitlistEntry)
          .includes(:service, :employee_membership, :customer_profile)
          .where.not(status: "dismissed")
          .order(:desired_date, :created_at)
          .map { |entry| waitlist_entry_payload(entry) }
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

      def calendar_notifications
        categories = {
          appointments: [],
          tips: [],
          sales: [],
          actions: []
        }

        @notification_center.all_items(limit: 20).each do |item|
          categories[notification_category(item)] << {
            title: item.title,
            body: item.body,
            time: relative_time_label(item.created_at),
            unread: item.unread?,
            actionLabel: item.action_label,
            actionUrl: item.action_url
          }
        end

        categories
      end

      def notification_category(item)
        case item.notification_type
        when "new_booking", "booking_cancelled", "deposit_approved", "deposit_rejected"
          :appointments
        when "new_deposit_proof", "follow_up_due", "waitlist_entry", "fillable_gap"
          :actions
        when "trial_ending", "subscription_overdue"
          :sales
        else
          :tips
        end
      end

      def relative_time_label(value)
        return "" if value.blank?

        helpers.time_ago_in_words(value) + " atrás"
      end

      def time_label(value)
        value.in_time_zone.strftime("%H:%M")
      end
  end
end
