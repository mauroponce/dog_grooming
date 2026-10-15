class GoogleAuthenticationController < ApplicationController
  allow_unauthenticated_access only: %i[callback failure]

  def callback
    identity = GoogleOAuth::Identity.from_omniauth(request.env.fetch("omniauth.auth"))

    if registration_flow?
      session[:google_registration_identity] = identity.session_attributes
      redirect_to registro_path
    elsif employee_invitation_token.present?
      accept_employee_invitation(identity)
    else
      sign_in(identity)
    end
  rescue GoogleOAuth::Identity::Invalid, KeyError
    redirect_to new_session_path, alert: "No pudimos verificar tu cuenta de Google. Probá de nuevo."
  end

  def failure
    redirect_to new_session_path, alert: "No pudimos ingresar con Google. Probá de nuevo."
  end

  private
    def registration_flow?
      request.env["omniauth.origin"] == "registration"
    end

    def employee_invitation_token
      origin = request.env["omniauth.origin"].to_s
      origin.delete_prefix("employee_invitation:") if origin.start_with?("employee_invitation:")
    end

    def accept_employee_invitation(identity)
      membership = EmployeeMembership.find_pending_by_token(employee_invitation_token)
      unless membership && membership.email_address.casecmp?(identity.email_address)
        redirect_to new_session_path, alert: "La invitación no existe, venció o corresponde a otro correo."
        return
      end

      if User.exists?(email_address: identity.email_address)
        redirect_to new_session_path, alert: "Ya existe un usuario con ese correo."
        return
      end

      user = User.transaction do
        invited_user = User.create!(email_address: identity.email_address, name: identity.name, google_uid: identity.uid, google_connected_at: Time.current, last_login_provider: "google", role: :employee)
        membership.accept!(user: invited_user)
        invited_user
      end
      start_new_session_for(user)
      redirect_to admin_root_path, notice: "Tu acceso fue creado."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to new_session_path, alert: "No pudimos crear tu acceso. Probá de nuevo."
    end

    def sign_in(identity)
      result = GoogleOAuth::SignIn.call(identity: identity)
      if result.success?
        start_new_session_for(result.user)
        redirect_to after_authentication_url
      elsif result.reason == :disabled
        redirect_to new_session_path, alert: "Tu usuario está deshabilitado."
      else
        redirect_to new_session_path, alert: "No encontramos una cuenta activa para ese correo."
      end
    end
end
