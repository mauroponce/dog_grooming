class AiChatConversation < ApplicationRecord
  STATUSES = %w[open summarized closed].freeze
  SUMMARY_STATUSES = %w[pending completed failed skipped].freeze

  belongs_to :business
  has_many :ai_chat_messages, dependent: :destroy

  before_validation :ensure_visitor_token
  before_validation :normalize_customer_phone

  validates :visitor_token, :status, :summary_status, presence: true
  validates :visitor_token, uniqueness: { scope: :business_id }
  validates :status, inclusion: { in: STATUSES }
  validates :summary_status, inclusion: { in: SUMMARY_STATUSES }

  scope :open, -> { where(status: "open") }
  scope :needs_summary, -> {
    open.where(summary_status: "pending").where("updated_at <= ?", 2.hours.ago)
  }

  def enough_activity_for_followup?
    ai_chat_messages.where(role: "user").count >= 2 && ai_chat_messages.count >= 4
  end

  def detected_customer_phone
    customer_phone.presence || phone_from_messages
  end

  private
    def ensure_visitor_token
      self.visitor_token ||= SecureRandom.hex(18)
    end

    def normalize_customer_phone
      self.customer_phone = PhoneNumber.normalize(customer_phone) if customer_phone.present?
    end

    def phone_from_messages
      text = ai_chat_messages.where(role: "user").order(:created_at).pluck(:content).join(" ")
      match = text.scan(/(?:\+?\d[\d\s().-]{7,}\d)/).first
      PhoneNumber.normalize(match) if match.present?
    end
end
