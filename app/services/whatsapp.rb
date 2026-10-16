module WhatsApp
  def self.automation_enabled?(business, recipient: nil)
    connection = business.whatsapp_connection
    return false unless connection&.connected? && connection.automation_enabled?
    return true if ENV["WHATSAPP_AUTOMATION_ENABLED"] == "true"

    demo_phone_number_id = ENV["WHATSAPP_DEMO_AUTOMATION_PHONE_NUMBER_ID"].to_s
    demo_recipient = PhoneNumber.normalize(ENV["WHATSAPP_DEMO_AUTOMATION_RECIPIENT"])
    demo_phone_number_id.present? && demo_recipient.present? &&
      connection.phone_number_id == demo_phone_number_id &&
      (PhoneNumber.normalize(recipient) == demo_recipient || demo_api_recipient?(business, recipient))
  end

  def self.outbound_recipient_for(business, recipient:)
    return recipient unless demo_connection_for?(business, recipient)

    ENV["WHATSAPP_DEMO_API_RECIPIENT"].to_s.delete("^0-9").presence || recipient
  end

  def self.demo_connection_for?(business, recipient)
    connection = business.whatsapp_connection
    demo_phone_number_id = ENV["WHATSAPP_DEMO_AUTOMATION_PHONE_NUMBER_ID"].to_s
    demo_recipient = PhoneNumber.normalize(ENV["WHATSAPP_DEMO_AUTOMATION_RECIPIENT"])

    demo_phone_number_id.present? && demo_recipient.present? &&
      connection&.phone_number_id == demo_phone_number_id &&
      PhoneNumber.normalize(recipient) == demo_recipient
  end

  def self.demo_api_recipient?(business, recipient)
    api_recipient = ENV["WHATSAPP_DEMO_API_RECIPIENT"].to_s.delete("^0-9")
    api_recipient.present? && ActiveSupport::SecurityUtils.secure_compare(recipient.to_s.delete("^0-9"), api_recipient)
  end
end
