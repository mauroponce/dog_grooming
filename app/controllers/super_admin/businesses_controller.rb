module SuperAdmin
  class BusinessesController < BaseController
    def index
      @dashboard = SuperAdmin::Dashboard.new(params: params)
      @business_rows = @dashboard.all_rows

      respond_to do |format|
        format.html
        format.csv do
          send_data @dashboard.to_csv,
            filename: "cita-pet-negocios-#{Time.zone.today.iso8601}.csv",
            type: "text/csv; charset=utf-8"
        end
      end
    end

    def new
      prepare_business_form
    end

    def edit
      prepare_business_form(business)
      @business_form_url = super_admin_business_path(business)
      @business_form_method = :patch
      @business_form_title = "Editar negocio"
      @business_form_description = "Actualizá la cuenta comercial y sus imágenes públicas. Los servicios se administran desde el panel del negocio."
      @business_form_after_title = "Después de editar"
      @business_form_after_description = "Los cambios se aplican al perfil público y al workspace del negocio."
      @business_form_submit_label = "Guardar cambios"
      render :new
    end

    def create
      result = SuperAdmin::CreateBusinessAccount.call(business_account_params)
      redirect_to edit_super_admin_business_path(result.business),
        notice: "Cuenta creada. El negocio puede cargar sus servicios desde su panel de administración."
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      prepare_business_form
      flash.now[:alert] = error.message
      render :new, status: :unprocessable_entity
    end

    def update
      result = SuperAdmin::UpdateBusinessAccount.call(business, business_account_params)
      redirect_to edit_super_admin_business_path(result.business),
        notice: "Negocio actualizado."
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      prepare_business_form(business)
      @business_form_url = super_admin_business_path(business)
      @business_form_method = :patch
      @business_form_title = "Editar negocio"
      @business_form_description = "Actualizá la cuenta comercial y sus imágenes públicas. Los servicios se administran desde el panel del negocio."
      @business_form_after_title = "Después de editar"
      @business_form_after_description = "Los cambios se aplican al perfil público y al workspace del negocio."
      @business_form_submit_label = "Guardar cambios"
      flash.now[:alert] = error.message
      render :new, status: :unprocessable_entity
    end

    def create_demo
      result = SuperAdmin::CreateDemoBusiness.call
      redirect_to super_admin_businesses_path(business_id: result.business.id),
        notice: "Demo creado. Admin: #{result.email}"
    end

    def destroy
      business_name = business.name
      business.destroy!
      redirect_to super_admin_businesses_path, notice: "Negocio #{business_name} eliminado."
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed => error
      redirect_to super_admin_businesses_path(business_id: business.id),
        alert: "No pudimos eliminar #{business.name}: #{error.message}"
    end

    def disable
      business.update!(disabled_at: Time.current)
      redirect_to super_admin_businesses_path(business_id: business.id), notice: "Negocio deshabilitado."
    end

    def enable
      business.update!(disabled_at: nil)
      redirect_to super_admin_businesses_path(business_id: business.id), notice: "Negocio habilitado."
    end

    def extend_trial
      current_end = [ business.trial_ends_at || Time.current, Time.current ].max
      new_end = current_end + 7.days

      business.transaction do
        business.update!(trial_ends_at: new_end)
        subscription = business.subscription
        if subscription.present? && !subscription.paid?
          old_due_on = subscription.next_due_on
          new_due_on = new_end.to_date
          subscription.update!(
            trial_ends_on: new_due_on,
            next_due_on: new_due_on,
            grace_ends_on: new_due_on + Business::BILLING_GRACE_DAYS.days,
            status: subscription.pending_review? ? "pending_review" : "trialing",
            suspended_at: nil,
            restricted_at: nil
          )
          invoice = subscription.current_invoice
          if invoice.present? && !invoice.paid? && (old_due_on.blank? || invoice.due_on == old_due_on)
            invoice.update!(
              due_on: new_due_on,
              period_start: new_due_on,
              period_end: new_due_on.advance(months: invoice.billing_period_months),
              status: invoice.pending_review? ? "pending_review" : "open",
              overdue_at: nil,
              suspended_at: nil,
              restricted_at: nil
            )
          end
        end
      end

      redirect_to super_admin_businesses_path(business_id: business.id),
        notice: "Trial extendido hasta #{helpers.format_ar_date(business.trial_ends_at)}."
    end

    def approve_payment
      invoice = current_invoice!
      Billing::ApprovePayment.call(invoice: invoice, reviewer: current_user)
      redirect_to super_admin_businesses_path(business_id: business.id), notice: "Pago aprobado."
    rescue StandardError => error
      redirect_to super_admin_businesses_path(business_id: business.id), alert: error.message
    end

    def reject_payment
      invoice = current_invoice!
      Billing::RejectPayment.call(invoice: invoice, reviewer: current_user, reason: params[:reason])
      redirect_to super_admin_businesses_path(business_id: business.id), notice: "Pago rechazado."
    rescue StandardError => error
      redirect_to super_admin_businesses_path(business_id: business.id), alert: error.message
    end

    def mark_paid
      invoice = current_invoice!
      Billing::ApprovePayment.call(invoice: invoice, reviewer: current_user, manual: true)
      redirect_to super_admin_businesses_path(business_id: business.id), notice: "Cuenta marcada como pagada."
    rescue StandardError => error
      redirect_to super_admin_businesses_path(business_id: business.id), alert: error.message
    end

    def send_billing_email
      invoice = current_invoice!
      BillingMailer.reminder(invoice, params[:reminder_type].presence || "due_today").deliver_later
      redirect_to super_admin_businesses_path(business_id: business.id), notice: "Email de cobro encolado."
    rescue StandardError => error
      redirect_to super_admin_businesses_path(business_id: business.id), alert: error.message
    end

    def extend_grace
      invoice = current_invoice!
      new_grace_end = [ invoice.subscription.effective_grace_ends_on || invoice.due_on, Time.zone.today ].max + 7.days
      invoice.subscription.update!(status: "overdue", grace_ends_on: new_grace_end, suspended_at: nil, restricted_at: nil)
      invoice.business.update!(disabled_at: nil)
      redirect_to super_admin_businesses_path(business_id: business.id), notice: "Gracia extendida hasta #{helpers.format_ar_date(new_grace_end)}."
    rescue StandardError => error
      redirect_to super_admin_businesses_path(business_id: business.id), alert: error.message
    end

    def restrict_billing
      invoice = current_invoice!
      invoice.update!(status: "overdue", restricted_at: Time.current)
      invoice.subscription.update!(status: "restricted", restricted_at: Time.current)
      redirect_to super_admin_businesses_path(business_id: business.id), notice: "Cuenta restringida."
    rescue StandardError => error
      redirect_to super_admin_businesses_path(business_id: business.id), alert: error.message
    end

    def suspend_billing
      invoice = current_invoice!
      invoice.update!(status: "overdue", suspended_at: Time.current)
      invoice.subscription.update!(status: "suspended", suspended_at: Time.current)
      redirect_to super_admin_businesses_path(business_id: business.id), notice: "Cuenta suspendida."
    rescue StandardError => error
      redirect_to super_admin_businesses_path(business_id: business.id), alert: error.message
    end

    def reactivate_billing
      subscription = business.subscription || business.create_subscription!(external_reference: "business-#{business.id}-#{SecureRandom.hex(6)}")
      subscription.update!(status: "payment_due", suspended_at: nil, restricted_at: nil, cancelled_at: nil)
      business.update!(disabled_at: nil)
      redirect_to super_admin_businesses_path(business_id: business.id), notice: "Cuenta reactivada con pago pendiente."
    rescue StandardError => error
      redirect_to super_admin_businesses_path(business_id: business.id), alert: error.message
    end

    def cancel_billing
      subscription = business.subscription || raise("La cuenta no tiene suscripción.")
      subscription.update!(status: "cancelled", cancelled_at: Time.current)
      redirect_to super_admin_businesses_path(business_id: business.id), notice: "Suscripción cancelada."
    rescue StandardError => error
      redirect_to super_admin_businesses_path(business_id: business.id), alert: error.message
    end

    private
      def business
        @business ||= Business.find(params[:id])
      end

      def current_invoice!
        Billing::EnsureCurrentInvoice.call(business: business, force: true) ||
          business.subscription&.current_invoice ||
          raise("No hay un cobro pendiente.")
      end

        def business_account_params
          params.require(:business_account).permit(
          :business_name,
          :billing_enabled,
          :owner_name,
            :owner_email,
            :contact_phone,
          :instagram_url,
          :slug,
          :custom_domain,
          :custom_domain_enabled,
          :slogan,
          :address,
          :address_details,
          :latitude,
          :longitude,
          :city,
          :province,
          :neighborhood,
          :logo,
          availability_rules: {}
        )
      end

      def prepare_business_form(business = nil)
        @business_form_business = business
        @business_account_values = business_account_form_values(business)
        @business_availability_rules = business_availability_rules_for_form(business)
      end

      def business_account_form_values(business)
        submitted = params[:business_account]
        return submitted.to_unsafe_h.symbolize_keys if submitted.present?
        return {} if business.blank?

          {
            business_name: business.name,
            owner_name: business.owner.name.presence || business.employee_memberships.find_by(user: business.owner)&.name || business.name,
            owner_email: business.owner.email_address,
          contact_phone: business.contact_phone,
          instagram_url: business.instagram_url,
          slug: business.slug,
          custom_domain: business.custom_domain,
          custom_domain_enabled: business.custom_domain_enabled?,
          slogan: business.slogan,
          billing_enabled: business.billing_enabled?,
          address: business.address,
          address_details: business.address_details,
          latitude: business.latitude,
          longitude: business.longitude,
          city: business.city,
          province: business.province,
          neighborhood: business.neighborhood
        }
      end

      def business_availability_rules_for_form(business)
        submitted = params.dig(:business_account, :availability_rules)
        return normalize_submitted_availability_rules(submitted) if submitted.present?

        rules_by_weekday = business&.availability_rules&.index_by(&:weekday) || {}
        Business::DAYS.map do |weekday, day_name|
          rule = rules_by_weekday[weekday]
          default_active = weekday.in?([ 1, 2, 3, 4, 5 ])
          {
            weekday: weekday,
            day_name: day_name,
            active: rule.present? ? rule.active? : default_active,
            start_time: formatted_time(rule&.start_time) || "10:00",
            end_time: formatted_time(rule&.end_time) || "19:00",
            break_start_time: formatted_time(rule&.break_start_time),
            break_end_time: formatted_time(rule&.break_end_time)
          }
        end
      end

      def normalize_submitted_availability_rules(submitted)
        rules = submitted.respond_to?(:to_unsafe_h) ? submitted.to_unsafe_h : submitted.to_h
        Business::DAYS.map do |weekday, day_name|
          values = rules[weekday.to_s] || {}
          {
            weekday: weekday,
            day_name: day_name,
            active: ActiveModel::Type::Boolean.new.cast(values["active"]),
            start_time: values["start_time"].presence || "10:00",
            end_time: values["end_time"].presence || "19:00",
            break_start_time: values["break_start_time"].presence,
            break_end_time: values["break_end_time"].presence
          }
        end
      end

      def formatted_time(value)
        value&.strftime("%H:%M")
      end
  end
end
