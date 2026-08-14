module SuperAdmin
  class ImpersonationsController < BaseController
    skip_before_action :require_super_admin!, only: :destroy
    before_action :require_impersonation!, only: :destroy

    def create
      business = Business.find(impersonated_business_id)
      impersonator_user_id = current_user.id
      start_new_session_for(business.owner)
      session[:impersonator_user_id] = impersonator_user_id
      redirect_to admin_root_path
    end

    def destroy
      impersonator = User.find_by(id: session[:impersonator_user_id])
      terminate_session
      start_new_session_for(impersonator) if impersonator
      session.delete(:impersonator_user_id)
      redirect_to super_admin_businesses_path, notice: "Uso de cuenta finalizado."
    end

    private
      def require_impersonation!
        redirect_to root_path, alert: "No hay uso de cuenta activo" if session[:impersonator_user_id].blank?
      end

      def impersonated_business_id
        params[:business_id].presence || params[:id]
      end
  end
end
