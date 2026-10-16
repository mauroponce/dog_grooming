module Admin
  class SettingsController < BaseController
    SETTINGS_TABS = %w[
      datos-generales
      pagina-de-reservas
      diseno-web
      cuentas-de-cobro
      horarios-de-atencion
      fechas-no-laborables
    ].freeze

    def show
      prepare_settings
    end

    def update
      Business.transaction do
        if params[:agenda].present?
          @business.lock!
          @business.assign_attributes(params.require(:agenda).permit(:simultaneous_capacity, :arrival_mode))
          if params[:agenda_times].present?
            @business.arrival_times = params.require(:agenda_times).permit(*("0".."6").to_a).to_h.transform_values { |value| value.to_s.split(/[,\s]+/).reject(&:blank?) }
          end
          @business.save!
        end
        Admin::UpdateBusinessSettings.call(@business, business_account_params) if params[:business_account].present?
        Admin::UpdateBookingPagePreferences.call(@business, booking_page_preferences_params) if params[:booking_page_preferences].present?
        Admin::UpdatePaymentPreferences.call(@business, payment_preferences_params) if params[:payment_preferences].present?
        Admin::SyncPaymentAccounts.call(@business, payment_accounts_params) if params[:payment_accounts].present?
        SuperAdmin::SyncBusinessAvailability.call(@business, availability_rules_params)
      end
      active_tab = settings_tab || SETTINGS_TABS.first
      redirect_to admin_settings_path(settings_tab: active_tab, anchor: active_tab), notice: "Configuración actualizada."
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      prepare_settings
      flash.now[:alert] = error.message
      render :show, status: :unprocessable_entity
    end

    private
      def prepare_settings
        @settings_active_tab = settings_tab || SETTINGS_TABS.first
        @settings_business_values = settings_business_values
        @settings_booking_page_preferences = settings_booking_page_preferences
        @settings_payment_accounts = settings_payment_accounts
        @settings_payment_preferences = settings_payment_preferences
        @settings_mercado_pago_connection = @business.mercado_pago_connection
        @settings_availability_rules = settings_availability_rules
        @settings_non_working_periods = @business.availability_blocks.non_working_periods.order(:starts_at).to_a
        @settings_time_options = (0...24.hours)
          .step(5.minutes)
          .map { |seconds| Time.zone.parse("00:00") + seconds }
          .map { |time| time.strftime("%H:%M") }
      end

      def availability_rules_params
        params.fetch(:availability_rules, ActionController::Parameters.new).permit!
      end

      def payment_accounts_params
        params.fetch(:payment_accounts, ActionController::Parameters.new).permit!
      end

      def payment_preferences_params
        params.require(:payment_preferences).permit(enabled_payment_methods: [])
      end

      def booking_page_preferences_params
        params.require(:booking_page_preferences).permit(:allow_professional_selection, :show_team_members, :assignment_strategy, :rescheduling_notice_hours)
      end

      def business_account_params
        params.require(:business_account).permit(
          :business_name,
          :owner_name,
          :owner_email,
          :contact_phone,
          :instagram_url,
          :slug,
          :slogan,
          :public_site_mode,
          :public_custom_css,
          :public_custom_html,
          :public_category_custom_html,
          :address,
          :address_details,
          :latitude,
          :longitude,
          :city,
          :province,
          :neighborhood,
          :logo
        )
      end

      def settings_business_values
        submitted = params[:business_account]
        return submitted.to_unsafe_h.symbolize_keys if submitted.present?

        {
          business_name: @business.name,
          owner_name: @business.owner.name.presence || @business.employee_memberships.find_by(user: @business.owner)&.name || @business.name,
          owner_email: @business.owner.email_address,
          contact_phone: @business.contact_phone,
          instagram_url: @business.instagram_url,
          slug: @business.slug,
          slogan: @business.slogan,
          public_site_mode: @business.public_site_mode,
          public_custom_css: @business.public_custom_css,
          public_custom_html: @business.public_custom_html,
          public_category_custom_html: @business.public_category_custom_html,
          address: @business.address,
          address_details: @business.address_details,
          latitude: @business.latitude,
          longitude: @business.longitude,
          city: @business.city,
          province: @business.province,
          neighborhood: @business.neighborhood
        }
      end

      def settings_payment_accounts
        return normalize_submitted_payment_accounts(params[:payment_accounts]) if params[:payment_accounts].present?

        @business.payment_accounts.ordered.to_a
      end

      def settings_payment_preferences
        submitted = params[:payment_preferences]
        return submitted.to_unsafe_h if submitted.respond_to?(:to_unsafe_h)
        return submitted.to_h if submitted.respond_to?(:to_h)

        { "enabled_payment_methods" => @business.enabled_payment_methods }
      end

      def settings_booking_page_preferences
        submitted = params[:booking_page_preferences]
        raw = if submitted.respond_to?(:to_unsafe_h)
          submitted.to_unsafe_h
        elsif submitted.respond_to?(:to_h)
          submitted.to_h
        else
          {}
        end
        return raw if raw.present?

        {
          "allow_professional_selection" => @business.public_booking_allow_professional_selection?,
          "show_team_members" => @business.public_booking_show_team_members?,
          "assignment_strategy" => @business.public_booking_assignment_strategy,
          "rescheduling_notice_hours" => @business.rescheduling_notice_hours
        }
      end

      def normalize_submitted_payment_accounts(submitted)
        raw = submitted.respond_to?(:to_unsafe_h) ? submitted.to_unsafe_h : submitted.to_h
        primary_key = raw["primary_key"].to_s

        raw.fetch("items", {}).map do |key, values|
          next if ActiveModel::Type::Boolean.new.cast(values["_destroy"])
          next if values["name"].to_s.blank? && values["details"].to_s.blank?

          account = values["id"].present? ? @business.payment_accounts.find_by(id: values["id"]) || @business.payment_accounts.build : @business.payment_accounts.build
          account.assign_attributes(
            name: values["name"].to_s,
            details: values["details"].to_s,
            primary_account: key.to_s == primary_key
          )
          account
        end.compact
      end

      def settings_availability_rules
        submitted = params[:availability_rules]
        return normalize_submitted_availability_rules(submitted) if submitted.present?

        rules_by_weekday = @business.availability_rules.index_by(&:weekday)
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
        return if value.blank?

        value.respond_to?(:strftime) ? value.strftime("%H:%M") : value.to_s
      end

      def settings_tab
        tab = params[:settings_tab].to_s
        tab if SETTINGS_TABS.include?(tab)
      end
  end
end
