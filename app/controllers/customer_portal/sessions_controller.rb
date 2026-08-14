module CustomerPortal
  class SessionsController < BaseController
    def new
      redirect_to customer_portal_dashboard_path(@business.slug) if customer_portal_authenticated?
    end

    def create
      CustomerPortal::MagicLinks::CreateService.call(
        business: @business,
        contact: params[:contact].presence || params[:email],
        request: request
      )

      redirect_to customer_portal_entry_path(@business.slug, sent: 1)
    end

    def show
      result = CustomerPortal::MagicLinks::ConsumeService.call(business: @business, token: params[:token])
      start_customer_portal_session!(email: result.email)
      redirect_to customer_portal_dashboard_path(@business.slug)
    rescue CustomerPortal::MagicLinks::ConsumeService::InvalidToken
      render :invalid, status: :unprocessable_entity
    end

    def profile
      token = params[:token].to_s
      customer = @business.customer_profiles.find_by(customer_portal_short_token: token) ||
        @business.customer_profiles.find_by!(customer_portal_token: token)
      start_customer_portal_session!(customer_profile: customer)
      redirect_to customer_portal_dashboard_path(@business.slug)
    rescue ActiveRecord::RecordNotFound
      render :invalid, status: :unprocessable_entity
    end

    def destroy
      reset_customer_portal_session!
      redirect_to public_business_path(@business.slug), notice: "Saliste del portal de turnos."
    end
  end
end
