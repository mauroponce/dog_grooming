class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 8, within: 10.minutes, only: :create, with: -> { redirect_to registro_path, alert: "Probá de nuevo más tarde." }

  def new
    redirect_to admin_root_path if authenticated?
  end

  def create
    result = Registrations::CreateBusinessAccount.call(registration_params)
    start_new_session_for(result.owner)
    redirect_to onboarding_schedule_path, notice: "¡Tu prueba de 14 días ya está activa! Configurá tus horarios para empezar."
  rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    @values = registration_params.to_h
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  def slug_suggestions
    render json: { suggestions: [ Slugs::GenerateUnique.call(params[:name].to_s, scope: Business) ] }
  end

  def slug_availability
    slug = Business.slug_for(params[:slug].to_s)
    render json: { available: slug.present? && Slugs::GenerateUnique.valid?(slug) && Slugs::GenerateUnique.available?(slug, scope: Business), slug: slug }
  end

  private
    def registration_params
      params.require(:registration).permit(:business_name, :owner_name, :email_address, :password, :password_confirmation, :contact_phone, :slug, :plan_selected)
    end
end
