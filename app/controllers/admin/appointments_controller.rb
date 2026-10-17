module Admin
  class AppointmentsController < BaseController
    def details
      payload = calendar_appointment_payload(appointment)
      payload[:detailVariant] = "customer-profile" if params[:context] == "customer_profile"

      render json: payload
    end

    def create
      prepare_form_collections
      saved = @business.with_lock do
        @appointment = build_manual_appointment
        authorize @appointment, :create?
        next false unless @appointment.save

        sync_manual_appointment_addons!(@appointment)
        mark_waitlist_entry_booked!(@appointment)
        true
      end

      if saved
        respond_to do |format|
          format.html { redirect_to admin_calendar_path, notice: "Turno creado." }
          format.json { render json: calendar_appointment_payload(@appointment), status: :created }
        end
      else
        respond_to do |format|
          format.html { redirect_to admin_calendar_path, alert: @appointment.errors.full_messages.to_sentence }
          format.json { render json: { errors: @appointment.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      errors = if error.respond_to?(:record) && error.record&.errors&.any?
        error.record.errors.full_messages
      else
        [ error.message ]
      end
      respond_to do |format|
        format.html { redirect_to admin_calendar_path, alert: errors.to_sentence }
        format.json { render json: { errors: errors }, status: :unprocessable_entity }
      end
    end

    def destroy
      unless policy(appointment).destroy?
        respond_to do |format|
          format.html { redirect_back fallback_location: admin_calendar_path, alert: "Solo se pueden eliminar turnos creados desde el calendario." }
          format.json { render json: { errors: [ "Solo se pueden eliminar turnos creados desde el calendario." ] }, status: :forbidden }
        end
        return
      end

      authorize appointment, :destroy?
      deleted_id = appointment.short_uuid
      appointment.destroy!

      respond_to do |format|
        format.html { redirect_to admin_calendar_path, notice: "Turno eliminado." }
        format.json { render json: { deleted: true, id: deleted_id } }
      end
    end

    def confirm
      if appointment.deposit_required? && appointment.deposit_status != "approved"
        authorize appointment, :approve_deposit?
        DepositProofs::ApproveService.new(appointment: appointment, actor: current_user).call
      else
        authorize appointment, :confirm?
        appointment.confirm!
      end
      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_back fallback_location: admin_calendar_path, notice: "Turno confirmado." }
      end
    end

    def approve_deposit
      authorize appointment, :approve_deposit?
      DepositProofs::ApproveService.new(appointment: appointment, actor: current_user).call
      respond_to do |format|
        format.html { redirect_to admin_appointment_path(appointment), notice: "Seña aprobada. El turno fue confirmado." }
        format.json { render json: calendar_appointment_payload(appointment) }
      end
    rescue StandardError => error
      respond_to do |format|
        format.html { redirect_to admin_appointment_path(appointment), alert: error.message }
        format.json { render json: { errors: [ error.message ] }, status: :unprocessable_entity }
      end
    end

    def mark_remaining_balance_paid
      authorize appointment, :update?

      unless appointment.remaining_balance_payable?
        respond_to do |format|
          format.html { redirect_back fallback_location: admin_calendar_path, alert: "El turno no tiene saldo pendiente para registrar." }
          format.json { render json: { errors: [ "El turno no tiene saldo pendiente para registrar." ] }, status: :unprocessable_entity }
        end
        return
      end

      appointment.mark_remaining_balance_paid!(paid_by: current_user)

      respond_to do |format|
        format.html { redirect_back fallback_location: admin_calendar_path, notice: "Saldo restante registrado como pagado." }
        format.json { render json: calendar_appointment_payload(appointment) }
      end
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_calendar_path, alert: error.message }
        format.json { render json: { errors: [ error.message ] }, status: :unprocessable_entity }
      end
    end

    def update_notes
      authorize appointment, :update?
      appointment.update!(internal_notes: appointment_notes_params[:internal_notes].to_s.strip.presence)

      render json: calendar_appointment_payload(appointment.reload)
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
    end

    def update_service_variant
      authorize appointment, :update?
      raise ArgumentError, "El tamaño sólo se puede corregir antes de que comience el turno." unless appointment.starts_at.future? && !appointment.terminal_status?

      variant = appointment.service.service_variants.active.find(service_variant_params[:service_variant_id])
      selected_service = Bookings::ServiceSelection.new(service: appointment.service, variant: variant)
      addon_price = appointment.appointment_addons.sum(:price_cents)
      appointment.update!(
        service_variant: variant,
        service_variant_name: variant.display_name,
        service_variant_price_cents: variant.price_cents,
        service_variant_duration_minutes: variant.duration_minutes,
        ends_at: appointment.starts_at + variant.duration_minutes.minutes,
        base_price_cents: variant.price_cents + addon_price,
        final_price_cents: selected_service.price_cents_for_time(appointment.starts_at, @business) + addon_price
      )
      appointment.pet&.update!(pet_size_band: variant.pet_size_band)
      render json: calendar_appointment_payload(appointment.reload)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ArgumentError => error
      render json: { errors: [ error.message ] }, status: :unprocessable_entity
    end

    def available_professionals
      authorize appointment, :update?

      render json: {
        professionals: assignable_professionals(appointment).map do |professional|
          {
            id: professional.id.to_s,
            name: professional.display_name,
            initials: professional.initials,
            specialty: professional.specialty_label,
            branchName: professional.branch&.name
          }
        end
      }
    end

    def change_professional
      authorize appointment, :update?
      professional = assignable_professionals(appointment).find_by(id: params.require(:employee_membership_id))
      raise ActiveRecord::RecordNotFound if professional.blank?

      appointment.with_lock do
        appointment.update!(employee_membership: professional)
      end

      render json: calendar_appointment_payload(appointment.reload)
    rescue ActionController::ParameterMissing
      render json: { errors: [ "Seleccioná un profesional." ] }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound
      render json: { errors: [ "Ese profesional no puede realizar este servicio." ] }, status: :unprocessable_entity
    end

    def reject_deposit
      authorize appointment, :reject_deposit?
      DepositProofs::RejectService.new(appointment: appointment, actor: current_user, reason: params[:reason]).call
      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_back fallback_location: admin_calendar_path, notice: "Comprobante rechazado." }
        format.json { render json: calendar_appointment_payload(appointment) }
      end
    rescue StandardError => error
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_calendar_path, alert: error.message }
        format.json { render json: { errors: [ error.message ] }, status: :unprocessable_entity }
      end
    end

    def download_receipt
      authorize appointment, :review_deposit?
      unless appointment.deposit_receipt.attached?
        redirect_to admin_appointment_path(appointment), alert: "Este comprobante no tiene archivo adjunto."
        return
      end

      appointment.deposit_receipt.open do |file|
        send_data file.read,
          filename: appointment.deposit_receipt.filename.to_s,
          type: appointment.deposit_receipt.content_type,
          disposition: "attachment"
      end
    rescue ActiveStorage::FileNotFoundError
      redirect_to admin_appointment_path(appointment), alert: "No encontramos el archivo del comprobante en el almacenamiento."
    end

    def upload_receipt
      authorize appointment, :approve_deposit?
      receipt = params.require(:deposit_receipt)
      appointment.deposit_receipt.attach(
        Storage::UploadAttachable.build(
          receipt,
          key: Storage::ObjectKeyBuilder.deposit_receipt(appointment, filename: receipt.original_filename)
        )
      )
      appointment.mark_deposit_submitted!
      appointment.business.provider_events.create!(
        user: current_user,
        event_type: "deposit_receipt_uploaded_manually",
        title: "Comprobante cargado manualmente",
        body: "#{current_user.email_address} cargó un comprobante para #{appointment.customer_name}.",
        metadata: {
          appointment_id: appointment.id,
          action_url: admin_appointment_url(appointment)
        }
      )
      redirect_to admin_appointment_path(appointment), notice: "Comprobante cargado para revisión."
    rescue ActionController::ParameterMissing
      redirect_to admin_appointment_path(appointment), alert: "Seleccioná una imagen o PDF del comprobante."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admin_appointment_path(appointment), alert: error.record.errors.full_messages.to_sentence.presence || "No pudimos guardar el comprobante."
    end

    def cancel
      authorize appointment, :cancel?
      cancellation_reason = params[:reason].to_s.strip.presence
      unless cancellation_reason
        respond_to do |format|
          format.turbo_stream { head :unprocessable_content }
          format.html { redirect_back fallback_location: admin_calendar_path, alert: "Indicá el motivo de la cancelación." }
          format.json { render json: { errors: [ "Indicá el motivo de la cancelación." ] }, status: :unprocessable_entity }
        end
        return
      end

      @business.transaction do
        appointment.cancel!(by: current_user, reason: cancellation_reason)
        create_cancellation_note!(appointment, cancellation_reason)
      end
      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_back fallback_location: admin_calendar_path, notice: "Turno cancelado." }
        format.json { render json: { id: appointment.short_uuid, status: appointment.status, canceledAt: appointment.canceled_at.iso8601 } }
      end
    end

    def finalize
      authorize appointment, :finalize?
      Appointments::FinalizeService.new(
        appointment: appointment,
        actor: current_user,
        params: finalization_params
      ).call

      if finalization_params[:outcome] == "rescheduled"
        redirect_to admin_calendar_path, notice: "Turno marcado como reprogramado. Creá el nuevo horario desde el calendario."
      else
        redirect_back fallback_location: admin_calendar_path, notice: finalization_notice(finalization_params[:outcome])
      end
    rescue Appointments::FinalizeService::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
      redirect_back fallback_location: admin_calendar_path, alert: finalization_error_message(error)
    end

    private
      def appointment
        @appointment ||= appointment_scope_with_details.find_by!(short_uuid: params[:short_uuid])
      end

      def appointment_scope_with_details
        policy_scope(@business.appointments)
          .includes(
            :service,
            :bookable_resource,
            :branch,
            :customer_profile,
            :pet,
            :canceled_by_user,
            :deposit_reviewed_by,
            :completed_by,
            :remaining_balance_paid_by,
            :appointment_payment,
            service: :payment_account,
            deposit_receipt_attachment: :blob,
            booking_notes: :created_by,
            booking_attachments: { file_attachment: :blob },
            employee_membership: :user
          )
      end

      def appointment_params
        params.require(:appointment).permit(
          :service_id,
          :service_variant_id,
          :bookable_resource_id,
          :branch_id,
          :employee_membership_id,
          :customer_profile_id,
          :waitlist_entry_id,
          :create_customer_profile,
          :customer_name,
          :customer_phone,
          :customer_email,
          :pet_id,
          :pet_name,
          :pet_breed,
          :pet_sex,
          :pet_birth_date,
          :pet_notes,
          :starts_at,
          :notes,
          :status,
          add_on_service_ids: []
        )
      end

      def appointment_notes_params
        params.require(:appointment).permit(:internal_notes)
      end

      def service_variant_params
        params.require(:appointment).permit(:service_variant_id)
      end

      def finalization_params
        params.require(:finalization).permit(:outcome, :body, :cancellation_reason, :follow_up_option, :follow_up_date, :employee_membership_id, photos: [])
      end

      def create_cancellation_note!(appointment, reason)
        return if reason.blank? || appointment.customer_profile.blank?

        appointment.booking_notes.create!(
          business: @business,
          customer_profile: appointment.customer_profile,
          employee_membership: current_employee_membership,
          created_by: current_user,
          note_type: "cancellation",
          body: reason
        )
      end

      def build_manual_appointment
        attrs = appointment_params.to_h.with_indifferent_access
        @manual_add_on_service_ids = Array(attrs.delete(:add_on_service_ids)).reject(&:blank?)
        requested_status = manual_appointment_status(attrs.delete(:status))
        service = @business.services.find(attrs[:service_id])
        service_variant = service.service_variants.active.find_by(id: attrs.delete(:service_variant_id))
        raise ArgumentError, "Elegí el tamaño de la mascota para este servicio." if service.tiered_pricing? && service_variant.blank?
        booking_service = Bookings::ServiceSelection.new(service: service, variant: service_variant)
        branch = branch_for(attrs)
        employee_membership = employee_membership_for(attrs)
        waitlist_entry = waitlist_entry_for(attrs)
        create_customer_profile = ActiveModel::Type::Boolean.new.cast(attrs.delete(:create_customer_profile))
        profile = selected_customer_profile(attrs)
        if profile
          attrs[:customer_name] = profile.name.presence || profile.phone
          attrs[:customer_phone] = profile.phone
          attrs[:customer_email] = profile.email
        end
        validate_customer_contact_details!(attrs)
        phone = PhoneNumber.normalize(attrs[:customer_phone])
        profile ||= customer_profile_for_manual_appointment(attrs, phone, create_customer_profile: create_customer_profile)
        pet = pet_for_manual_appointment(attrs, profile, pet_size_band: service_variant&.pet_size_band)

        starts_at = Time.zone.parse(attrs[:starts_at].to_s)
        employee_membership ||= assign_professional_for(booking_service, starts_at)
        resource = resource_for(attrs, booking_service, starts_at)
        @business.appointments.new(attrs.merge(
          service: service,
          service_variant: service_variant,
          branch: branch,
          waitlist_entry: waitlist_entry,
          employee_membership: employee_membership,
          bookable_resource: resource,
          customer_profile: profile,
          pet: pet,
          source: :manual,
          status: requested_status,
          confirmed_at: requested_status == :confirmed ? Time.current : nil,
          deposit_status: manual_deposit_status_for(requested_status),
          deposit_amount_cents: manual_deposit_amount_for(service, requested_status),
          ends_at: starts_at + (booking_service.duration_minutes + manual_add_on_services.sum(&:duration_minutes)).minutes,
          base_price_cents: booking_service.price_cents + manual_add_on_services.sum(&:price_cents),
          final_price_cents: booking_service.price_cents_for_time(starts_at, @business) + manual_add_on_services.sum { |add_on| add_on.price_cents_for_time(starts_at, @business) },
          service_variant_name: service_variant&.display_name,
          service_variant_price_cents: service_variant&.price_cents,
          service_variant_duration_minutes: service_variant&.duration_minutes,
          discount_percentage: service.dynamic_discount_for_time(starts_at, @business)
        ))
      end

      def manual_add_on_services
        @manual_add_on_services ||= begin
          by_id = @business.services.active.where(id: @manual_add_on_service_ids).index_by { |service| service.id.to_s }
          @manual_add_on_service_ids.filter_map { |id| by_id[id.to_s] }
        end
      end

      def sync_manual_appointment_addons!(appointment)
        manual_add_on_services.each do |service|
          appointment.appointment_addons.create!(service: service, price_cents: service.price_cents_for_time(appointment.starts_at, @business))
        end
      end

      def mark_waitlist_entry_booked!(appointment)
        return unless appointment.waitlist_entry

        appointment.waitlist_entry.update!(
          status: "booked",
          accepted_at: Time.current,
          released_appointment: appointment
        )
      end

      def selected_customer_profile(attrs)
        customer_profile_id = attrs.delete(:customer_profile_id)
        return if customer_profile_id.blank?

        @business.customer_profiles.find(customer_profile_id)
      end

      def waitlist_entry_for(attrs)
        waitlist_entry_id = attrs.delete(:waitlist_entry_id)
        return if waitlist_entry_id.blank?

        @business.waitlist_entries.visible.find(waitlist_entry_id)
      end

      def customer_profile_for_manual_appointment(attrs, normalized_phone, create_customer_profile: false)
        if normalized_phone.blank?
          return unless create_customer_profile

          return @business.customer_profiles.create!(
            name: attrs[:customer_name],
            phone: attrs[:customer_phone],
            email: attrs[:customer_email]
          )
        end

        Customers::UpsertProfile.call(
          business: @business,
          name: attrs[:customer_name],
          phone: attrs[:customer_phone],
          email: attrs[:customer_email]
        )
      end

      def pet_for_manual_appointment(attrs, profile, pet_size_band: nil)
        selected_pet_id = attrs.delete(:pet_id)
        attributes = {
          name: attrs.delete(:pet_name),
          breed: attrs.delete(:pet_breed),
          sex: attrs.delete(:pet_sex),
          birth_date: attrs.delete(:pet_birth_date),
          notes: attrs.delete(:pet_notes)
        }

        return if selected_pet_id.blank? && attributes.values.all?(&:blank?)
        raise ArgumentError, "Seleccioná o agregá una mascota para este turno." if profile.blank?

        selected_pet = profile.pets.find(selected_pet_id) if selected_pet_id.present?
        Pets::Upsert.call(
          business: @business,
          customer_profile: profile,
          pet: selected_pet,
          pet_size_band: pet_size_band,
          **attributes
        )
      end

      def validate_customer_contact_details!(attrs)
        raise ArgumentError, "Completá el teléfono del cliente." if attrs[:customer_phone].blank?
        raise ArgumentError, "Completá el email del cliente." if attrs[:customer_email].blank?
        raise ArgumentError, "Ingresá un email válido." unless attrs[:customer_email].to_s.match?(URI::MailTo::EMAIL_REGEXP)
      end

      def manual_appointment_status(value)
        case value.to_s
        when "pending_deposit"
          :pending_deposit
        when "pending"
          :pending
        else
          :confirmed
        end
      end

      def manual_deposit_status_for(status)
        status == :pending_deposit ? "pending" : "not_required"
      end

      def manual_deposit_amount_for(service, status)
        status == :pending_deposit ? service.expected_deposit_amount_cents : 0
      end

      def assignable_professionals(appointment)
        relation = @business.employee_memberships.available_for_booking.includes(:branch).order(:sort_order, :name)
        assigned_ids = appointment.service.employee_membership_ids
        relation = relation.where(id: assigned_ids) if assigned_ids.any?
        relation
      end

      def calendar_appointment_payload(appointment)
        customer_profile = appointment.customer_profile
        status = calendar_status(appointment)
        appointment_addons = appointment.appointment_addons.includes(:service).to_a
        appointment_services = [
          { id: appointment.service_id.to_s, name: appointment.service.name, duration: appointment.service_variant_duration_minutes || appointment.service.duration_minutes, price: (appointment.service_variant_price_cents || appointment.service.price_cents) / 100 }
        ] + appointment_addons.map { |addon| { id: addon.service_id.to_s, name: addon.service.name, duration: addon.service.duration_minutes, price: addon.service.price_cents / 100 } }
        {
          id: appointment.short_uuid,
          employeeId: appointment.employee_membership_id.present? ? appointment.employee_membership_id.to_s : "center",
          employeeName: appointment.employee_membership&.display_name || @business.name,
          startsAt: appointment.starts_at.iso8601,
          dateISO: appointment.starts_at.to_date.iso8601,
          start: appointment.starts_at.in_time_zone.strftime("%H:%M"),
          finish: appointment.ends_at.in_time_zone.strftime("%H:%M"),
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
          customerProfileId: appointment.customer_profile_id&.to_s,
          customerProfileUrl: appointment.customer_profile_id.present? ? edit_admin_customer_profile_path(appointment.customer_profile_id, return_to: admin_calendar_path(date: appointment.starts_at.to_date.iso8601, t: appointment.short_uuid)) : nil,
          customerProfilePanelUrl: appointment.customer_profile_id.present? ? panel_admin_customer_profile_path(appointment.customer_profile_id, format: :json) : nil,
          customerPortalUrl: customer_portal_url_for(customer_profile),
          customerCreatedAt: customer_profile&.created_at&.to_date&.iso8601,
          customerSummary: customer_summary_payload_for(customer_profile),
          status: status,
          statusLabel: admin_appointment_status_label(status),
          color: calendar_appointment_color(appointment, status:),
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

      def calendar_status(appointment)
        return "completed" if appointment.confirmed? && appointment.ends_at <= Time.current

        appointment.status
      end

      def calendar_appointment_color(appointment, status: calendar_status(appointment))
        return "#f4f4f5" if appointment.canceled? || appointment.no_show? || appointment.expired?
        return "#fef3c7" if appointment.pending_deposit_review? || appointment.deposit_status == "submitted"
        return "#ffe4e6" if appointment.pending_deposit? || appointment.deposit_rejected? || appointment.deposit_status.in?(%w[pending rejected failed])
        return "#ffded4" if status == "completed"
        return "#ffded4" if appointment.pending? || (appointment.confirmed? && appointment.starts_at < Time.current)

        "#d1fae5"
      end

      def prepare_form_collections
        @services = @business.services.active
        @resources = @business.bookable_resources.active.order(:name)
        @branches = @business.branches.active.order(:name)
        @employee_memberships = employee_memberships_for_forms
      end

      def employee_memberships_for_forms
        if current_employee_membership&.can?("can_view_all_bookings") || current_user.admin? || current_user.super_admin?
          @business.employee_memberships.available_for_booking.includes(:user, :branch).order(:name)
        else
          [ current_employee_membership ].compact.select(&:can_receive_appointments?)
        end
      end

      def finalization_notice(outcome)
        case outcome
        when "no_show" then "Turno marcado como no asistió."
        when "cancelled" then "Turno cancelado con nota interna."
        else "Turno guardado en el historial de la clienta."
        end
      end

      def finalization_error_message(error)
        return error.record.errors.full_messages.to_sentence if error.respond_to?(:record) && error.record&.errors&.any?

        error.message
      end

      def branch_for(attrs)
        return current_employee_membership.branch if current_employee_membership.present? && !current_employee_membership.can?("can_view_all_bookings")
        return @business.branches.find(attrs[:branch_id]) if attrs[:branch_id].present?

        @business.branches.active.order(:name).first
      end

      def employee_membership_for(attrs)
        return current_employee_membership if current_employee_membership.present? && !current_employee_membership.can?("can_view_all_bookings")
        return @business.employee_memberships.available_for_booking.find(attrs[:employee_membership_id]) if attrs[:employee_membership_id].present?

        nil
      end

      def resource_for(attrs, service, starts_at)
        return @business.bookable_resources.find(attrs[:bookable_resource_id]) if attrs[:bookable_resource_id].present?

        ends_at = starts_at + service.duration_minutes.minutes
        Resources::Availability.new(business: @business, service: service, starts_at: starts_at, ends_at: ends_at).first_available(lock: true)
      end

      def assign_professional_for(service, starts_at)
        return unless @business.team_features_available?

        Bookings::AssignProfessionalService.call(
          business: @business,
          service: service,
          starts_at: starts_at
        )
      rescue Bookings::AssignProfessionalService::UnavailableProfessional
        nil
      end
  end
end
