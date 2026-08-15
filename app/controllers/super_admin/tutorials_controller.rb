module SuperAdmin
  class TutorialsController < BaseController
    InvalidTutorialOrder = Class.new(StandardError)

    before_action :set_tutorial, only: %i[edit update destroy]

    def index
      @tutorials = Tutorial.ordered
    end

    def new
      @tutorial = Tutorial.new
    end

    def create
      @tutorial = Tutorial.new(tutorial_params.merge(sort_order: next_sort_order))

      if @tutorial.save
        redirect_to super_admin_tutorials_path, notice: "Tutorial creado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @tutorial.update(tutorial_params)
        redirect_to super_admin_tutorials_path, notice: "Tutorial actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @tutorial.destroy!
      redirect_to super_admin_tutorials_path, notice: "Tutorial eliminado."
    end

    def reorder
      reorder_tutorials!
      head :no_content
    rescue ActionController::ParameterMissing, InvalidTutorialOrder
      render json: { error: "El orden de tutoriales no es válido." }, status: :unprocessable_entity
    end

    private
      def set_tutorial
        @tutorial = Tutorial.find(params[:id])
      end

      def tutorial_params
        params.require(:tutorial).permit(:title, :video_url)
      end

      def next_sort_order
        Tutorial.maximum(:sort_order).to_i + 1
      end

      def reorder_tutorials!
        tutorial_ids = Array(params.require(:tutorial_ids)).map { |id| Integer(id) }
        raise InvalidTutorialOrder if tutorial_ids.uniq.size != tutorial_ids.size

        Tutorial.transaction do
          current_ids = Tutorial.lock.order(:id).pluck(:id)
          raise InvalidTutorialOrder unless current_ids == tutorial_ids.sort

          updated_at = Time.current
          tutorial_ids.each_with_index do |id, index|
            Tutorial.where(id: id).update_all(sort_order: index, updated_at: updated_at)
          end
        end
      rescue ArgumentError, TypeError
        raise InvalidTutorialOrder
      end
  end
end
