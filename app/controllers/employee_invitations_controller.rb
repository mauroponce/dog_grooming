class EmployeeInvitationsController < ApplicationController
  allow_unauthenticated_access only: %i[show update]

  before_action :set_membership

  def show
    @user = User.new(email_address: @membership.email_address)
  end

  def update
    if User.exists?(email_address: @membership.email_address)
      redirect_to new_session_path, alert: "Ya existe un usuario con este correo. Pedile al administrador que use otro correo para la invitación."
      return
    end

    User.transaction do
      @user = User.create!(user_params.merge(email_address: @membership.email_address, role: :employee))
      @membership.accept!(user: @user)
      start_new_session_for(@user)
    end

    redirect_to admin_root_path, notice: "Tu acceso fue creado."
  rescue ActiveRecord::RecordInvalid => error
    @user ||= User.new(email_address: @membership.email_address)
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_entity
  end

  private
    def set_membership
      @membership = EmployeeMembership.find_pending_by_token(params[:token])
      redirect_to new_session_path, alert: "La invitación no existe o venció." unless @membership
    end

    def user_params
      params.require(:user).permit(:password, :password_confirmation)
    end
end
