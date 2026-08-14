module CustomerPortal
  class DashboardController < BaseController
    before_action :require_customer_portal_session!

    def show
      load_dashboard
    end

    def update
      profile = primary_customer_profile

      if profile.update(customer_profile_params)
        start_customer_portal_session!(customer_profile: profile)
        redirect_to customer_portal_dashboard_path(@business.slug, anchor: "profile"), notice: "Tus datos fueron actualizados."
      else
        load_dashboard
        @customer_profile = profile
        flash.now[:alert] = profile.errors.full_messages.to_sentence.presence || "No pudimos actualizar tus datos."
        render :show, status: :unprocessable_entity
      end
    end

    private
      def load_dashboard
        @customer_profiles = customer_profiles_for_session.order(updated_at: :desc)
        @customer_profile = primary_customer_profile
        @upcoming_appointments = portal_appointments_scope
          .active
          .where("starts_at >= ?", Time.current)
          .includes(:business, :service, :branch, :employee_membership, :pet, appointment_addons: :service)
          .order(:starts_at)
          .limit(20)
        @pending_deposit_appointments = @upcoming_appointments.select { |appointment| appointment.pending_deposit? || appointment.deposit_rejected? || appointment.pending_deposit_review? }
        @history_appointments = portal_appointments_scope
          .where("starts_at < ? OR status IN (?)", Time.current, Appointment.statuses.values_at(*Appointment::TERMINAL_STATUSES))
          .includes(:business, :service, :branch, :employee_membership, :pet, appointment_addons: :service)
          .order(starts_at: :desc)
          .limit(24)
        @history = @history_appointments
      end

      def primary_customer_profile
        @primary_customer_profile ||= customer_profiles_for_session.order(updated_at: :desc).first
      end

      def customer_profile_params
        params.require(:customer_profile).permit(:first_name, :last_name, :phone, :email)
      end
  end
end
