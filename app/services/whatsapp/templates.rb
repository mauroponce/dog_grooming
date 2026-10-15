module WhatsApp
  class Templates
    def self.ensure!(connection)
      client = CloudClient.new
      [ connection.confirmation_template, connection.reminder_template ].each do |name|
        existing = client.get!("#{connection.waba_id}/message_templates?#{URI.encode_www_form(name: name)}", token: connection.access_token).fetch("data")
        next if existing.any? { |item| item["name"] == name && item["language"] == connection.template_language }

        intro = name == connection.reminder_template ? "Recordatorio de turno" : "Turno confirmado"
        client.post!("#{connection.waba_id}/message_templates", {
          name: name, language: connection.template_language, category: "UTILITY",
          components: [ { type: "BODY", text: "#{intro}: {{1}} tiene un turno para {{2}} el {{3}} en {{4}}.", example: { body_text: [ [ "Coco", "Baño chico", "16/10/2026 10:00", "Pichipurris" ] ] } } ]
        }, token: connection.access_token)
      end
    end
  end
end
