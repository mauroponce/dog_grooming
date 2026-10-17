module Admin
  class CustomerProfilesController < BaseController
    CUSTOMER_EDITOR_SECTIONS = %w[personal pets appointments notes photos].freeze

    def index
      @customer_query = Customers::InboxQuery.new(
        business: @business,
        customers_scope: customer_scope,
        appointments_scope: appointment_scope,
        params: params,
        current_user: current_user
      )
      @pagy, customers = pagy_collection(@customer_query.customers_relation, limit: 20)
      @customers = customers.to_a
      @customer_presenters_by_id = build_customer_presenters(@customers)

      respond_to do |format|
        format.html
        format.csv do
          send_data @customer_query.to_csv,
            filename: "clientes-#{Time.zone.today.iso8601}.csv",
            type: "text/csv; charset=utf-8"
        end
      end
    end

    def new
      require_customer_edit_permission!
      @customer = @business.customer_profiles.new
    end

    def show
      redirect_to edit_admin_customer_profile_path(customer, section: params[:section], return_to: customer_editor_return_to)
    end

    def edit
      require_customer_edit_permission!
      @customer = customer
      load_customer_editor
    end

    def panel
      selected_customer = customer
      page = [ params[:page].to_i, 1 ].max
      limit = 10
      relation = appointment_scope
        .where(customer_profile: selected_customer)
        .includes(:service, :employee_membership, :branch)
        .order(starts_at: :desc, id: :desc)
      appointments = relation.offset((page - 1) * limit).limit(limit + 1).to_a
      has_more = appointments.length > limit
      completed_relation = relation.where.not(status: Appointment.statuses.values_at("canceled", "no_show", "expired"))

      render json: {
        customer: customer_panel_payload(
          selected_customer,
          relation.count,
          total_sales_cents: completed_relation.sum(Arel.sql("COALESCE(final_price_cents, base_price_cents, 0)")),
          canceled_count: relation.where(status: Appointment.statuses["canceled"]).count,
          no_show_count: relation.where(status: Appointment.statuses["no_show"]).count
        ),
        appointments: appointments.first(limit).map { |appointment| customer_panel_appointment_payload(appointment) },
        page: page,
        has_more: has_more
      }
    end

    def autocomplete
      query = params[:q].to_s.strip
      page = [ params[:page].to_i, 1 ].max
      limit = 20
      relation = autocomplete_customers(query)
      customers = relation.offset((page - 1) * limit).limit(limit + 1).to_a
      has_more = customers.length > limit
      customers = customers.first(limit)
      appointments_by_customer = latest_appointments_by_customer(customers)
      appointment_counts = appointment_counts_by_customer(customers)
      pets_by_customer_id = pets_by_customer(customers)

      render json: {
        page: page,
        has_more: has_more,
        results: customers.map do |profile|
          latest_appointment = appointments_by_customer[profile.id]&.first
          {
            id: profile.id,
            name: profile.name.presence || profile.phone,
            initials: customer_initials(profile),
            phone: profile.phone,
            email: profile.email,
            url: edit_admin_customer_profile_path(profile),
            subtitle: autocomplete_subtitle(profile, latest_appointment),
            meta: autocomplete_meta(profile, appointment_counts[profile.id].to_i),
            pets: pets_by_customer_id.fetch(profile.id, []).map { |pet| pet_autocomplete_payload(pet) }
          }
        end
      }
    end

    def create
      require_customer_edit_permission!
      profile = @business.customer_profiles.new(customer_params)
      if profile.save
        redirect_to edit_admin_customer_profile_path(profile), notice: "Cliente registrado."
      else
        handle_customer_create_failure(profile)
      end
    end

    def update
      require_customer_edit_permission!
      selected_customer = customer
      attributes = customer_params
      photos = attributes.delete(:customer_photos)
      validate_customer_photos!(selected_customer, photos)
      selected_customer.update!(attributes)
      attach_customer_photos!(selected_customer, photos)
      redirect_to edit_admin_customer_profile_path(selected_customer, section: editor_section, return_to: customer_editor_return_to), notice: "Cliente actualizado."
    rescue ActiveRecord::RecordInvalid => error
      @customer = error.record
      load_customer_editor
      render :edit, status: :unprocessable_entity
    end

    def destroy_photo
      require_customer_edit_permission!
      attachment = customer.customer_photos.attachments.find(params[:attachment_id])
      attachment.purge
      redirect_to edit_admin_customer_profile_path(customer, section: "photos", return_to: customer_editor_return_to), notice: "Foto eliminada."
    end

    def destroy_pet_reference_photo
      require_customer_edit_permission!
      pet = customer.pets.find(params[:pet_id])
      pet.grooming_reference_photo.purge if pet.grooming_reference_photo.attached?
      redirect_to edit_admin_customer_profile_path(customer, section: "pets", return_to: customer_editor_return_to), notice: "Foto de referencia eliminada."
    end

    def destroy
      require_customer_edit_permission!
      selected_customer = customer
      selected_customer.soft_delete!
      redirect_to admin_customer_profiles_path, notice: "Cliente eliminado permanentemente."
    end

    def block
      require_customer_edit_permission!
      customer.block!(params[:blocked_reason])
      redirect_back fallback_location: admin_customer_profiles_path, notice: "Cliente bloqueado."
    end

    def unblock
      require_customer_edit_permission!
      customer.unblock!
      redirect_back fallback_location: admin_customer_profiles_path, notice: "Cliente desbloqueado."
    end

    def send_portal_access
      selected_customer = customer
      contact = selected_customer.email
      if contact.blank?
        redirect_back fallback_location: edit_admin_customer_profile_path(selected_customer), alert: "El cliente no tiene email cargado."
        return
      end

      CustomerPortal::MagicLinks::CreateService.call(
        business: @business,
        contact: contact,
        request: request
      )
      redirect_back fallback_location: edit_admin_customer_profile_path(selected_customer), notice: "Si el contacto tiene reservas asociadas, enviamos el acceso al portal."
    end

    private
      def customer_scope
        return @business.customer_profiles if current_user.admin? || current_user.super_admin?

        membership = current_employee_membership
        return @business.customer_profiles.none if membership.blank?
        return @business.customer_profiles if membership.can?("can_view_all_customers")

        customer_ids = @business.appointments.where(employee_membership: membership).where.not(customer_profile_id: nil).select(:customer_profile_id)
        @business.customer_profiles.where(id: customer_ids)
      end

      def appointment_scope
        @appointment_scope ||= policy_scope(@business.appointments)
      end

      def load_customer_editor
        @customer_editor_section = editor_section
        @customer_editor_return_to = customer_editor_return_to
        @customer.pets.build unless @customer.pets.any?(&:new_record?)
        pet_appointments = appointment_scope.where(customer_profile: @customer).where.not(pet_id: nil)
        @pet_appointment_counts = pet_appointments.group(:pet_id).count
        @pet_latest_appointments = pet_appointments.select("DISTINCT ON (pet_id) appointments.*").order(:pet_id, starts_at: :desc, id: :desc).index_by(&:pet_id)
        @customer_appointments_pagy, appointments = pagy_collection(
          appointment_scope
          .where(customer_profile: @customer)
          .includes(:service, { employee_membership: :user }, { canceled_by_user: :employee_memberships })
          .order(starts_at: :desc, id: :desc),
          limit: 20
        )
        @customer_appointments = appointments.to_a
      end

      def editor_section
        params[:section].presence_in(CUSTOMER_EDITOR_SECTIONS) || "personal"
      end

      def customer_editor_return_to
        candidate = params[:return_to].to_s
        path = candidate.split("?", 2).first

        candidate if path == admin_calendar_path
      end

      def build_customer_presenters(customers)
        customer_ids = customers.map(&:id)
        appointments_by_customer_id = if customer_ids.any?
          appointment_scope
            .where(customer_profile_id: customer_ids)
            .includes(:service, :bookable_resource, :branch, employee_membership: :user)
            .order(starts_at: :desc, id: :desc)
            .to_a
            .group_by(&:customer_profile_id)
        else
          {}
        end

        customers.each_with_object({}) do |customer, presenters|
          presenters[customer.id] = Customers::ProfilePresenter.new(
            customer: customer,
            business: @business,
            appointments_scope: appointment_scope,
            current_user: current_user,
            appointments: appointments_by_customer_id.fetch(customer.id, [])
          )
        end
      end

      def customer
        @customer ||= customer_scope.with_attached_customer_photos.find(params[:id])
      end

      def validate_customer_photos!(selected_customer, photos)
        uploads = Array(photos).compact_blank
        return if uploads.blank?

        if selected_customer.customer_photos.size + uploads.size > CustomerProfile::CUSTOMER_PHOTO_LIMIT
          selected_customer.errors.add(:customer_photos, "admite hasta #{CustomerProfile::CUSTOMER_PHOTO_LIMIT} fotos")
        end

        uploads.each do |photo|
          unless photo.content_type.to_s.in?(CustomerProfile::CUSTOMER_PHOTO_CONTENT_TYPES)
            selected_customer.errors.add(:customer_photos, "debe ser JPG, PNG o WebP")
          end

          if photo.size.to_i > CustomerProfile::CUSTOMER_PHOTO_MAX_SIZE
            selected_customer.errors.add(:customer_photos, "no puede superar 10 MB")
          end
        end

        raise ActiveRecord::RecordInvalid, selected_customer if selected_customer.errors.any?
      end

      def attach_customer_photos!(selected_customer, photos)
        Array(photos).compact_blank.each do |photo|
          selected_customer.customer_photos.attach(
            Storage::UploadAttachable.build(
              photo,
              key: Storage::ObjectKeyBuilder.customer_photo(selected_customer, filename: photo.original_filename)
            )
          )
        end
      end

      def autocomplete_customers(query)
        relation = customer_scope
          .left_joins(:appointments)
          .group("customer_profiles.id")

        if query.present?
          term = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
          normalized_phone = PhoneNumber.normalize(query)
          phone_term = "%#{ActiveRecord::Base.sanitize_sql_like(normalized_phone.presence || query)}%"
          relation = relation.where(
            "customer_profiles.name ILIKE :term OR customer_profiles.phone ILIKE :term OR customer_profiles.normalized_phone ILIKE :phone_term OR customer_profiles.email ILIKE :term",
            term: term,
            phone_term: phone_term
          )
        end

        relation.order(Arel.sql("MAX(appointments.starts_at) DESC NULLS LAST, customer_profiles.updated_at DESC, customer_profiles.id DESC"))
      end

      def latest_appointments_by_customer(customers)
        ids = customers.map(&:id)
        return {} if ids.blank?

        appointment_scope
          .where(customer_profile_id: ids)
          .includes(:service)
          .order(starts_at: :desc)
          .group_by(&:customer_profile_id)
      end

      def appointment_counts_by_customer(customers)
        ids = customers.map(&:id)
        return {} if ids.blank?

        appointment_scope.where(customer_profile_id: ids).group(:customer_profile_id).count
      end

      def pets_by_customer(customers)
        ids = customers.map(&:id)
        return {} if ids.blank?

        @business.pets.where(customer_profile_id: ids).alphabetically.to_a.group_by(&:customer_profile_id)
      end

      def pet_autocomplete_payload(pet)
        {
          id: pet.id.to_s,
          name: pet.name,
          breed: pet.breed,
          sex: pet.sex,
          sexLabel: pet.sex_label,
          notes: pet.notes
        }
      end

      def autocomplete_subtitle(profile, latest_appointment)
        [ profile.phone, latest_appointment&.service&.name ].compact_blank.join(" · ")
      end

      def autocomplete_meta(profile, appointments_count)
        return "Cliente bloqueada" if profile.blocked?
        return "Sin turnos registrados" if appointments_count.zero?
        return "1 turno registrado" if appointments_count == 1

        "#{appointments_count} turnos registrados"
      end

      def customer_initials(profile)
        name = profile.name.presence || profile.phone
        name.to_s.split.first(2).map { |part| part[0] }.join.upcase.presence || "HT"
      end

      def customer_panel_payload(profile, appointments_count, total_sales_cents:, canceled_count:, no_show_count:)
        {
          id: profile.id.to_s,
          name: profile.name.presence || profile.phone,
          initials: customer_initials(profile),
          phone: profile.phone,
          email: profile.email,
          gender: profile.gender_label,
          birthDate: profile.birth_date&.iso8601,
          createdAt: profile.created_at.to_date.iso8601,
          blocked: profile.blocked?,
          blockedReason: profile.blocked_reason,
          appointmentsCount: appointments_count,
          totalSales: total_sales_cents / 100,
          canceledCount: canceled_count,
          noShowCount: no_show_count,
          profileUrl: edit_admin_customer_profile_path(profile),
          portalUrl: profile.customer_portal_url,
          phone: profile.phone
        }
      end

      def customer_panel_appointment_payload(appointment)
        {
          id: appointment.short_uuid,
          date: appointment.starts_at.to_date.iso8601,
          startsAt: appointment.starts_at.iso8601,
          start: appointment.starts_at.in_time_zone.strftime("%H:%M"),
          duration: [ ((appointment.ends_at - appointment.starts_at) / 60).round, 15 ].max,
          service: appointment.service.name,
          professional: appointment.employee_membership&.name || @business.name,
          branch: appointment.branch&.name || @business.name,
          status: appointment.status_label,
          price: (appointment.final_price_cents.presence || appointment.base_price_cents.presence || appointment.service.price_cents) / 100,
          calendarUrl: admin_calendar_path(t: appointment.short_uuid, date: appointment.starts_at.to_date.iso8601)
        }
      end

      def customer_params
        permitted = params.require(:customer_profile).permit(
          :first_name,
          :last_name,
          :name,
          :phone,
          :email,
          :birth_date,
          :gender,
          :internal_notes,
          customer_photos: [],
          pets_attributes: [ :id, :name, :breed, :sex, :birth_date, :notes, :coat_type, :coat_details, :grooming_reference_note, :grooming_reference_photo, { behavioral_alerts: [] } ]
        )
        permitted[:birth_date] = parsed_birth_date if birth_date_parts_present?
        permitted
      end

      def birth_date_parts_present?
        profile_params[:birth_day].present? || profile_params[:birth_month].present? || profile_params[:birth_year].present?
      end

      def parsed_birth_date
        day = profile_params[:birth_day].to_i
        month = profile_params[:birth_month].to_i
        year = profile_params[:birth_year].to_i
        return if day.zero? || month.zero? || year.zero?

        Date.new(year, month, day)
      rescue Date::Error
        nil
      end

      def profile_params
        params.fetch(:customer_profile, {})
      end

      def handle_customer_create_failure(profile)
        if params[:source] == "new_customer_page"
          @customer = profile
          render :new, status: :unprocessable_entity
        else
          redirect_to admin_customer_profiles_path, alert: profile.errors.full_messages.to_sentence
        end
      end

      def require_customer_edit_permission!
        return if current_user.admin? || current_user.super_admin? || current_employee_membership&.can?("can_edit_customers")

        raise Pundit::NotAuthorizedError
      end
  end
end
