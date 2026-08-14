module WhatsApp
  module AutomatedNotifications
    module_function

    # Evolution stays available for the manual actions that open WhatsApp, but
    # no background process may contact a customer or a business by default.
    def enabled?
      ActiveModel::Type::Boolean.new.cast(
        ENV.fetch("AUTOMATED_WHATSAPP_NOTIFICATIONS_ENABLED", "false")
      )
    end
  end
end
