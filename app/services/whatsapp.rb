module WhatsApp
  def self.automation_enabled?(business = nil)
    return false unless ENV["WHATSAPP_AUTOMATION_ENABLED"] == "true"
    return true unless business

    connection = business.whatsapp_connection
    connection&.connected? && connection.automation_enabled?
  end
end
