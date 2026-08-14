module Admin
  class TutorialsController < BaseController
    def show
      @tutorials = Tutorial.ordered.to_a
      @selected_tutorial = @tutorials.find { |tutorial| tutorial.id == params[:tutorial_id].to_i } || @tutorials.first
    end
  end
end
