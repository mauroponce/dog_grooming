module SuperAdmin
  class BaseController < ApplicationController
    before_action :require_super_admin!

    private
      def require_super_admin!
        redirect_to root_path, alert: "No autorizado" unless current_user&.super_admin?
      end
  end
end
