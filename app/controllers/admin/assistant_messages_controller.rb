module Admin
  class AssistantMessagesController < BaseController
    def create
      answer = Ai::AdminDashboardAssistant.new(
        business: @business,
        question: params[:question],
        history: params[:history]
      ).call

      render json: { answer: answer }
    rescue ArgumentError => error
      render json: { error: error.message }, status: :unprocessable_entity
    rescue StandardError => error
      if error.message.include?("GEMINI_API_KEY")
        render json: { error: "GEMINI_API_KEY no está configurada." }, status: :service_unavailable
        return
      end

      Rails.logger.warn("Admin assistant failed for business #{@business&.id}: #{error.class}: #{error.message}")
      render json: { error: "No pude responder ahora. Probá de nuevo en unos segundos." }, status: :bad_gateway
    end
  end
end
