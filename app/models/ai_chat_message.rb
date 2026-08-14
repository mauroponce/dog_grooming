class AiChatMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :ai_chat_conversation, touch: true

  validates :role, :content, presence: true
  validates :role, inclusion: { in: ROLES }

  scope :user, -> { where(role: "user") }
  scope :assistant, -> { where(role: "assistant") }

  def assistant?
    role == "assistant"
  end
end
