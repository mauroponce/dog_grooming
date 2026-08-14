class ChatsController < ApplicationController
  allow_unauthenticated_access

  before_action :set_business

  def create
    unless @business.ai_chat_available?
      render json: { error: "El chat no está disponible para este negocio." }, status: :not_found
      return
    end

    message = chat_params[:message].to_s.strip
    if message.blank?
      render json: { error: "Escribí una consulta." }, status: :unprocessable_entity
      return
    end

    conversation = current_conversation
    conversation.update!(status: "open", summary_status: "pending") unless conversation.summary_status == "pending"
    conversation.ai_chat_messages.create!(role: "user", content: message)
    result = Ai::BusinessChat.new(business: @business).call(conversation: conversation)
    conversation.update!(last_intent: result.fetch(:intent))
    conversation.ai_chat_messages.create!(
      role: "assistant",
      content: result.fetch(:answer),
      metadata: {
        intent: result.fetch(:intent),
        recommended_service_ids: result.fetch(:recommended_service_ids),
        components: result.fetch(:components, []),
        tool_results: result.fetch(:tool_results, [])
      }
    )

    render json: result
  rescue ActionController::ParameterMissing
    render json: { error: "Escribí una consulta." }, status: :unprocessable_entity
  rescue StandardError => error
    Rails.logger.warn("AI chat failed for business #{@business.id}: #{error.class} #{error.message}")
    render json: { error: "No pude responder en este momento." }, status: :unprocessable_entity
  end

  private
    def set_business
      @business = Business.find_by_custom_domain(request.host) || Business.find_by!(slug: params[:slug])
    end

    def chat_params
      params.require(:chat).permit(:message)
    end

    def current_conversation
      token = cookies.permanent.signed[:ai_chat_visitor_token].presence || SecureRandom.hex(18)
      cookies.permanent.signed[:ai_chat_visitor_token] = token
      @business.ai_chat_conversations.find_or_create_by!(visitor_token: token)
    end
end
