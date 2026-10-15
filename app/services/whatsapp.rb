module WhatsApp
  def self.automation_enabled?
    ENV["WHATSAPP_AUTOMATION_ENABLED"] == "true"
  end
end
