class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 1.hour, only: :create,
    with: -> { redirect_to registro_path, alert: "Intentá de nuevo más tarde." }

  def new
    redirect_to admin_root_path if authenticated?
  end

  def create
    result = SelfRegistration::CreateAccount.call(registration_params)
    start_new_session_for(result.owner)
    redirect_to admin_root_path, notice: "Tu cuenta está lista. Tenés 14 días de prueba."
  rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    @registration_values = registration_params.to_h.except("password", "password_confirmation")
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  private
    def registration_params
      params.require(:registration).permit(:business_name, :owner_name, :owner_email, :contact_phone, :password, :password_confirmation)
    end
end
