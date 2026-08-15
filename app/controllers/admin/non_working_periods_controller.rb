module Admin
  class NonWorkingPeriodsController < BaseController
    def create
      period = @business.availability_blocks.new(period_attributes)

      if period.save
        redirect_to settings_section_path, notice: "Fecha no laborable añadida."
      else
        redirect_to settings_section_path, alert: period.errors.full_messages.to_sentence
      end
    rescue Date::Error, ArgumentError => error
      redirect_to settings_section_path, alert: error.message
    end

    def destroy
      @business.availability_blocks.non_working_periods.find(params[:id]).update!(cancelled_at: Time.current)

      redirect_to settings_section_path, notice: "Fecha no laborable eliminada."
    end

    private
      def period_attributes
        starts_on = localized_date!(period_params[:starts_on])
        ends_on = localized_date!(period_params[:ends_on])
        raise ArgumentError, "La fecha hasta debe ser posterior a la fecha desde." if ends_on <= starts_on

        {
          starts_at: starts_on.beginning_of_day,
          ends_at: (ends_on + 1.day).beginning_of_day,
          block_type: "non_working_period",
          reason: "Fecha no laborable",
          recurrence: "none",
          online_booking_allowed: false,
          created_by: current_user
        }
      end

      def period_params
        params.require(:non_working_period).permit(:starts_on, :ends_on)
      end

      def localized_date!(value)
        formatted_value = value.to_s.strip
        return Date.iso8601(formatted_value) if formatted_value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        return Date.strptime(formatted_value, "%d/%m/%Y") if formatted_value.match?(/\A\d{2}\/\d{2}\/\d{4}\z/)

        raise ArgumentError, "Elegí ambas fechas desde el calendario."
      end

      def settings_section_path
        admin_settings_path(settings_tab: "fechas-no-laborables", anchor: "fechas-no-laborables")
      end
  end
end
