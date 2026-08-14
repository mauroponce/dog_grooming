class ProviderEvent < ApplicationRecord
  belongs_to :business
  belongs_to :user, optional: true

  validates :event_type, :title, presence: true

  scope :for_business, ->(business) { where(business:) }
  scope :for_user, ->(user) { user.present? ? where(user_id: [ nil, user.id ]) : where(user_id: nil) }
  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  after_commit :enqueue_owner_whatsapp_notification_later, on: :create
  after_commit :enqueue_owner_email_notification_later, on: :create

  private
    def enqueue_owner_whatsapp_notification_later
      return unless WhatsApp::AutomatedNotifications.enabled?
      return unless WhatsApp::OwnerNotification.supported_event_type?(event_type)

      SendOwnerWhatsAppNotificationJob.perform_later(id)
    end

    def enqueue_owner_email_notification_later
      return unless event_type.in?(%w[customer_cancelled_booking booking_cancelled])

      SendOwnerEmailNotificationJob.perform_later(id)
    end
end
