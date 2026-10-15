class SessionsController < ApplicationController
  allow_unauthenticated_access only: :new

  def new
    redirect_to after_authentication_url if authenticated?
  end

  def destroy
    terminate_session
    session.delete(:impersonator_user_id)
    redirect_to new_session_path, status: :see_other
  end
end
