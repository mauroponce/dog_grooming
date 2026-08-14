module Admin
  class HomeController < BaseController
    def show
      @dashboard = Admin::HomeDashboard.new(
        business: @business,
        appointments_scope: policy_scope(@business.appointments),
        current_user: current_user
      )
      @upcoming_appointments_pagy, upcoming_appointments = pagy_collection(
        @dashboard.upcoming_appointments_scope,
        limit: 10,
        page_key: "upcoming_page"
      )
      @upcoming_appointments = upcoming_appointments.to_a
    end
  end
end
