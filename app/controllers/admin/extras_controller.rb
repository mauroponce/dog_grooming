module Admin
  class ExtrasController < BaseController
    before_action :set_extra, only: :update

    def create
      @extra = @business.extras.new(extra_params)
      if @extra.save
        redirect_to admin_services_path(panel: "extras"), notice: "Extra creado."
      else
        redirect_to admin_services_path(panel: "extras"), alert: @extra.errors.full_messages.to_sentence
      end
    end

    def update
      if @extra.update(extra_params)
        redirect_to admin_services_path(panel: "extras"), notice: "Extra actualizado."
      else
        redirect_to admin_services_path(panel: "extras"), alert: @extra.errors.full_messages.to_sentence
      end
    end

    private
      def set_extra
        @extra = @business.extras.find(params[:id])
      end

      def extra_params
        params.require(:extra).permit(:title, :description, :price, :public_visible, :active)
      end
  end
end
