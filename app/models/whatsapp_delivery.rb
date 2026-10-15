class WhatsAppDelivery < ApplicationRecord
  belongs_to :business
  belongs_to :appointment, optional: true
  after_create_commit -> { WhatsApp::SendDeliveryJob.perform_later(id) }

  def self.enqueue!(business:, key:, purpose:, payload:, appointment: nil, trial_reminder: false)
    create_or_find_by!(dedupe_key: key) do |delivery|
      delivery.assign_attributes(business: business, phone_number_id: business.whatsapp_connection&.phone_number_id, purpose: purpose, payload: payload, appointment: appointment, trial_reminder: trial_reminder)
    end
  end

  def self.monthly_usage(month: Time.current)
    start = month.in_time_zone.beginning_of_month
    scope = where(created_at: start...start.next_month)
    scope.group(:phone_number_id).count.map do |number_id, total|
      number = scope.where(phone_number_id: number_id)
      { phone_number_id: number_id, outgoing: total, accepted: number.where.not(accepted_at: nil).count,
        delivered: number.where.not(delivered_at: nil).count, read: number.where.not(read_at: nil).count,
        failed: number.where(status: "failed").count,
        billable: number.where("billing_metadata @> ?", { pricing: { billable: true } }.to_json).count }
    end
  end
end
