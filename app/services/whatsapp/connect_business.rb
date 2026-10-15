module WhatsApp
  class ConnectBusiness
    def self.call(business:, code:, waba_id:, phone_number_id:)
      raise ArgumentError, "Identificadores de Meta inválidos" unless [ waba_id, phone_number_id ].all? { |value| value.to_s.match?(/\A\d+\z/) }

      client = CloudClient.new
      app_token = "#{ENV.fetch('META_APP_ID')}|#{ENV.fetch('META_APP_SECRET')}"
      token = client.get!("oauth/access_token?#{URI.encode_www_form(client_id: ENV.fetch('META_APP_ID'), client_secret: ENV.fetch('META_APP_SECRET'), code: code)}", token: app_token).fetch("access_token")
      # Never trust WABA/phone IDs supplied by browser session logging alone.
      phones = client.get!("#{waba_id}/phone_numbers?fields=id,is_on_biz_app&limit=100", token: token).fetch("data")
      phone = phones.find { |item| item["id"] == phone_number_id && item["is_on_biz_app"] == true }
      raise ArgumentError, "La línea debe estar vinculada en coexistencia con WhatsApp Business." unless phone

      client.post!("#{waba_id}/subscribed_apps", {}, token: token)
      business.with_lock do
        connection = business.whatsapp_connection || business.build_whatsapp_connection
        connection.assign_attributes(phone_number_id: phone_number_id, waba_id: waba_id, access_token: token, disconnected_at: nil, templates_approved: false)
        connection.save!
        connection
      end
    end
  end
end
