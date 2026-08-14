module Internal
  class CaddyController < ActionController::Base
    def tls_permission
      return head :not_found unless request.host == "web"

      head(Business.find_by_custom_domain(params[:domain]).present? ? :ok : :not_found)
    end
  end
end
