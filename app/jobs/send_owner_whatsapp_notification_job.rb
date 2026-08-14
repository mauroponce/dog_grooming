class SendOwnerWhatsAppNotificationJob < ApplicationJob
  queue_as :default

  def perform(provider_event_id)
    return unless WhatsApp::AutomatedNotifications.enabled?

    event = ProviderEvent.find_by(id: provider_event_id)
    return if event.blank?

    WhatsApp::OwnerNotification.new(event).deliver
  end
end
