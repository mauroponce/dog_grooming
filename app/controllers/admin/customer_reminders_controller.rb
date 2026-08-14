module Admin
  class CustomerRemindersController < BaseController
    def create
      customer = scoped_customers.find(params[:customer_profile_id])
      reminder = CustomerReminders::CreateService.new(
        customer: customer,
        business: @business,
        actor: current_user,
        attributes: reminder_params
      ).call
      redirect_back fallback_location: admin_customer_profiles_path(customer_id: customer.id), notice: "Recordatorio creado para #{CustomerDateFormatter.datetime_label(reminder.remind_at)}."
    rescue ActiveRecord::RecordInvalid => error
      redirect_back fallback_location: admin_customer_profiles_path(customer_id: params[:customer_profile_id]), alert: error.record.errors.full_messages.to_sentence
    end

    def resolve
      customer = scoped_customers.find(params[:customer_profile_id])
      reminder = customer.customer_reminders.find(params[:id])
      reminder.resolve!(actor: current_user)
      redirect_back fallback_location: admin_customer_profiles_path(customer_id: customer.id), notice: "Recordatorio marcado como resuelto."
    end

    private
      def reminder_params
        params.require(:customer_reminder).permit(:body, :remind_at, :assigned_to_id)
      end

      def scoped_customers
        return @business.customer_profiles if current_user.admin? || current_user.super_admin?

        membership = current_employee_membership
        return @business.customer_profiles.none if membership.blank?
        return @business.customer_profiles if membership.can?("can_view_all_customers")

        customer_ids = @business.appointments.where(employee_membership: membership).where.not(customer_profile_id: nil).select(:customer_profile_id)
        @business.customer_profiles.where(id: customer_ids)
      end
  end
end
