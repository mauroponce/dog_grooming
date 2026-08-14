class IncomingWhatsAppEvent < ApplicationRecord
  self.table_name = "incoming_whatsapp_events"

  belongs_to :business, optional: true

  validates :instance_name, :event_type, :received_at, presence: true

  scope :recent, -> { order(created_at: :desc) }

  before_validation :set_received_at

  private
    def set_received_at
      self.received_at ||= Time.current
    end
end
