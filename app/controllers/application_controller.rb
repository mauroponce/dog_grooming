require "pagy"

class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include Pagy::Method
  include PublicUrlRouting

  helper PublicUrlRouting

  before_action :restrict_custom_domains_to_public_routes

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :current_business, :impersonating?

  private
    CUSTOM_DOMAIN_PUBLIC_CONTROLLERS = %w[
      appointment_actions
      campaign_links
      chats
      customer_portal/bookings
      customer_portal/dashboard
      customer_portal/sessions
      deposit_receipts
      public_booking
      public_service_pages
      waitlist_confirmations
      waitlist_entries
    ].freeze

    def restrict_custom_domains_to_public_routes
      return unless Business.find_by_custom_domain(request.host)
      return if controller_path.in?(CUSTOM_DOMAIN_PUBLIC_CONTROLLERS)

      head :not_found
    end

    def current_user
      Current.user
    end

    def current_business
      current_user&.primary_business
    end

    def impersonating?
      session[:impersonator_user_id].present? && authenticated?.present?
    end

    def after_authentication_url
      return super_admin_businesses_url if current_user&.super_admin?

      admin_root_url
    end

    def user_not_authorized
      redirect_to admin_calendar_path, alert: "No tenés permisos para realizar esta acción."
    end

    def pagy_collection(collection, limit: 20, **options)
      pagy(:offset, collection, limit:, **options)
    end
end
