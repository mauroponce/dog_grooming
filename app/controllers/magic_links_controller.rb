class MagicLinksController < ApplicationController
  allow_unauthenticated_access only: %i[new create show]
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Probá de nuevo más tarde." }

  def new
    redirect_to new_session_path
  end

  def create
    if params[:website].present?
      redirect_to new_session_path, notice: "Si existe una cuenta con ese email, te enviamos un enlace de acceso."
      return
    end

    user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
    StaffAccessMailer.magic_link(user).deliver_later if user&.disabled? == false

    redirect_to new_session_path, notice: "Si existe una cuenta con ese email, te enviamos un enlace de acceso."
  end

  def show
    user = User.find_signed!(params[:token], purpose: :staff_magic_login)
    if user.disabled?
      redirect_to new_session_path, alert: "Tu usuario está deshabilitado."
      return
    end

    user.update!(last_login_provider: "magic_link")
    start_new_session_for(user)
    redirect_to after_authentication_url
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to new_session_path, alert: "El enlace de acceso no es válido o venció."
  end
end
