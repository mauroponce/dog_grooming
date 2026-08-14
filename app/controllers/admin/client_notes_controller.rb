module Admin
  class ClientNotesController < BaseController
    def create
      raise Pundit::NotAuthorizedError unless current_user.admin? || current_user.super_admin? || current_employee_membership&.can?("can_edit_internal_notes")

      customer = scoped_customers.find(params[:customer_profile_id])
      note = customer.client_notes.new(client_note_params.merge(business: @business, user: current_user))
      note.save!
      redirect_back fallback_location: admin_customer_profiles_path(customer_id: customer.id), notice: "Nota agregada."
    rescue ActiveRecord::RecordInvalid => error
      redirect_back fallback_location: admin_customer_profiles_path(customer_id: customer.id), alert: error.record.errors.full_messages.to_sentence
    end

    private
      def client_note_params
        params.require(:client_note).permit(:title, :note_type, :body)
      end

      def scoped_customers
        return @business.customer_profiles if current_user.admin? || current_user.super_admin?
        return @business.customer_profiles.none if current_employee_membership.blank?
        return @business.customer_profiles if current_employee_membership.can?("can_view_all_customers")

        customer_ids = @business.appointments.where(employee_membership: current_employee_membership).where.not(customer_profile_id: nil).select(:customer_profile_id)
        @business.customer_profiles.where(id: customer_ids)
      end
  end
end
