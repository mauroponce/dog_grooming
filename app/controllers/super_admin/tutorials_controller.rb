module SuperAdmin
  class TutorialsController < BaseController
    before_action :set_tutorial, only: %i[edit update destroy]

    def index
      @tutorials = Tutorial.ordered
    end

    def new
      @tutorial = Tutorial.new
    end

    def create
      @tutorial = Tutorial.new(tutorial_params)

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

    private
      def set_tutorial
        @tutorial = Tutorial.find(params[:id])
      end

      def tutorial_params
        params.require(:tutorial).permit(:title, :video_url)
      end
  end
end
