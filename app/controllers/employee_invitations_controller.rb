class EmployeeInvitationsController < ApplicationController
  allow_unauthenticated_access only: :show

  before_action :set_membership

  def show
    @user = User.new(email_address: @membership.email_address)
  end

  private
    def set_membership
      @membership = EmployeeMembership.find_pending_by_token(params[:token])
      redirect_to new_session_path, alert: "La invitación no existe o venció." unless @membership
    end
end
