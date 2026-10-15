class WhatsAppDelivery < ApplicationRecord
  belongs_to :business
  belongs_to :appointment, optional: true
  after_create_commit -> { WhatsApp::SendDeliveryJob.perform_later(id) }

  def self.enqueue!(business:, key:, purpose:, payload:, appointment: nil, trial_reminder: false)
    create_or_find_by!(dedupe_key: key) do |delivery|
      delivery.assign_attributes(business: business, purpose: purpose, payload: payload, appointment: appointment, trial_reminder: trial_reminder)
    end
  end
end
