module WhatsApp
  module SignupConfiguration
    def self.configured?
      ENV["META_APP_ID"].present? && ENV["META_APP_SECRET"].present? && ENV["META_CONFIG_ID"].present?
    end

    def self.v4_confirmed?
      ENV["META_EMBEDDED_SIGNUP_V4_CONFIRMED"] == "true"
    end

    def self.graph_version
      ENV["WHATSAPP_GRAPH_API_VERSION"].presence || ENV.fetch("META_GRAPH_VERSION", "v25.0")
    end
  end
end
