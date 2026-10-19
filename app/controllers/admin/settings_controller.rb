module Admin
  class SettingsController < BaseController
    SETTINGS_TABS = %w[
      datos-generales
      pagina-de-reservas
      agenda-y-disponibilidad
      cobros-y-senas
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
        @settings_mercado_pago_connection = @business.mercado_pago_connection
        @settings_availability_rules = settings_availability_rules
        @settings_non_working_periods = @business.availability_blocks.non_working_periods.order(:starts_at).to_a
        @settings_time_options = (0...24.hours)
          .step(5.minutes)
          .map { |seconds| Time.zone.parse("00:00") + seconds }
          .map { |time| time.strftime("%H:%M") }
      end

      def availability_rules_params
        permitted_rules = Business::DAYS.map(&:first).map do |weekday|
          { weekday.to_s => %i[active start_time end_time break_start_time break_end_time] }
        end

        params.fetch(:availability_rules, ActionController::Parameters.new).permit(*permitted_rules)
      end

      def business_account_params
        params.require(:business_account).permit(
          :business_name,
          :owner_name,
          :owner_email,
          :contact_phone,
          :mobile_area_code,
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
          mobile_area_code: @business.mobile_area_code,
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
