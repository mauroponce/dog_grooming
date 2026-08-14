class SummarizeAiChatConversationsJob < ApplicationJob
  queue_as :default

  def perform
    return unless Ai::GeminiClient.available?

    Business.find_each do |business|
      next unless business.chatbot_enabled?

      business.ai_chat_conversations.needs_summary.find_each do |conversation|
        if conversation.enough_activity_for_followup?
          Ai::ConversationSummary.new(conversation: conversation).call
        else
          conversation.update!(summary_status: "skipped")
        end
      end
    end
  end
end
