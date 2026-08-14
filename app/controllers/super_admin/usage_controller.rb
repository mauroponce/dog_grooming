module SuperAdmin
  class UsageController < BaseController
    def show
      @dashboard = SuperAdmin::Dashboard.new(params: ActionController::Parameters.new)
      @usage = SuperAdmin::UsageDashboard.new
    end
  end
end
