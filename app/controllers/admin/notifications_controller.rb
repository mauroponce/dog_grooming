module Admin
  class NotificationsController < BaseController
    before_action :set_notification, only: %i[mark_read destroy]

    def mark_all_read
      @business.provider_events.unread.update_all(read_at: Time.current, updated_at: Time.current)

      redirect_back fallback_location: admin_home_path
    end

    def mark_read
      authorize @notification, :mark_read?
      @notification.update!(read_at: Time.current) if @notification.read_at.blank?

      head :no_content
    end

    def destroy
      authorize @notification, :destroy?
      @notification.destroy!

      redirect_back fallback_location: admin_home_path, notice: "Notificación eliminada."
    end

    private
      def set_notification
        @notification = @business.provider_events.find(params[:id])
      end
  end
end
