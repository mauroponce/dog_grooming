module WhatsApp
  class Bot
    def initialize(event:, contact:)
      @event, @contact, @business = event, contact, event.business
    end

    def call
      choice = @event.payload.dig("interactive", "list_reply", "id").to_s
      if choice == "human"
        @contact.update!(paused_until: 24.hours.from_now)
        send_payload(text("Te va a responder una persona de #{@business.name}. La atención automática queda pausada por 24 horas."), purpose: "handoff")
      elsif choice.start_with?("services:")
        menu(page: choice.delete_prefix("services:").to_i)
      elsif choice.start_with?("category:")
        category_id, page = choice.delete_prefix("category:").split(":")
        category = @business.service_categories.active.find_by(id: category_id)
        return menu unless category

        services = category.services.publicly_bookable.order(:sort_order, :name)
        page = [ page.to_i, 0 ].max
        rows = services.offset(page * 8).limit(8).map do |service|
          { id: "service:#{service.id}", title: service.name.truncate(24), description: "#{service.name} · $#{service.price_cents / 100} · #{service.duration_minutes} min".truncate(72) }
        end
        rows << { id: "category:#{category.id}:#{page + 1}", title: "Ver más servicios" } if services.count > (page + 1) * 8
        rows << { id: "human", title: "Hablar con una persona" }
        rows.empty? ? menu : send_payload(list("Elegí el servicio para tu mascota", rows))
      elsif choice.start_with?("service:")
        service = @business.services.publicly_bookable.find_by(id: choice.delete_prefix("service:"))
        return menu unless service

        @contact.update!(opted_in_at: Time.current)

        intent = @business.booking_intents.create!(service: service, full_name: @contact.name.presence || "Responsable de mascota", phone_e164: @contact.phone, expires_at: 2.hours.from_now, metadata: { source: "whatsapp" })
        token = intent.signed_id(expires_in: 2.hours, purpose: :whatsapp_booking)
        url = Rails.application.routes.url_helpers.whatsapp_booking_url(token: token, host: AppUrl.host, protocol: AppUrl.protocol)
        send_payload(text("Perfecto, ahora reservá tu turno aquí: #{url}"))
      elsif @contact.last_menu_at.nil? || @contact.last_menu_at < 24.hours.ago || @event.payload.dig("text", "body").to_s.strip.casecmp?("menu") || @event.payload.dig("text", "body").to_s.strip.casecmp?("menú")
        menu
      end
    end

    private
      def menu(page: 0)
        services = @business.services.publicly_bookable.order(:sort_order, :name, :id)
        total = services.count
        size = total > 9 ? 8 : 9
        page = 0 unless page.between?(0, [ (total - 1) / size, 0 ].max)
        rows = services.offset(page * size).limit(size).map do |service|
          { id: "service:#{service.id}", title: service.name.truncate(24), description: "$#{service.price_cents / 100} · #{service.duration_minutes} min".truncate(72) }
        end
        if total > 9
          next_page = (page + 1) * size < total ? page + 1 : 0
          rows << { id: "services:#{next_page}", title: next_page.zero? ? "Volver al inicio" : "Ver más servicios" }
        end
        rows << { id: "human", title: "Hablar con una persona" }
        @contact.update!(last_menu_at: Time.current)
        send_payload(list("Bienvenido a #{@business.name}, ¿en qué te puedo ayudar?", rows))
      end

      def text(body)
        { type: "text", text: { body: body } }
      end

      def list(body, rows)
        { type: "interactive", interactive: { type: "list", body: { text: body }, action: { button: "Elegir opción", sections: [ { title: "Opciones", rows: rows } ] } } }
      end

      def send_payload(payload, purpose: "reply")
        recipient = @contact.whatsapp_id.presence || @contact.phone.delete_prefix("+")
        recipient = WhatsApp.outbound_recipient_for(@business, recipient: recipient)
        WhatsAppDelivery.enqueue!(business: @business, key: "reply:#{@event.id}", purpose: purpose, payload: payload.merge(to: recipient))
      end
  end
end
