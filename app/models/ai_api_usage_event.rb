class AiApiUsageEvent < ApplicationRecord
  belongs_to :business, optional: true

  STATUSES = %w[success error].freeze

  validates :provider, :feature, :request_started_at, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :prompt_tokens, :completion_tokens, :total_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :gemini, -> { where(provider: "gemini") }
  scope :successful, -> { where(status: "success") }
  scope :errored, -> { where(status: "error") }
end
