module WhatsApp
  class ConnectBusiness
    FINISH_EVENT = "FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING".freeze
    PERMISSIONS = %w[whatsapp_business_management whatsapp_business_messaging].freeze

    def self.call(**attributes)
      new(**attributes).call
    end

    def initialize(business:, code:, event:, waba_id: nil, phone_number_id: nil)
      @business, @code, @event = business, code, event
      @waba_id, @phone_number_id = waba_id.presence, phone_number_id.presence
      @client = CloudClient.new
    end

    def call
      raise ArgumentError, "Solo se permite conectar WhatsApp Business App en coexistencia." unless @event == FINISH_EVENT
      raise ArgumentError, "La configuración v4 todavía no fue confirmada." unless SignupConfiguration.v4_confirmed?
      raise ArgumentError, "Código de autorización ausente." if @code.blank?
      raise ArgumentError, "Identificadores de Meta inválidos." unless [ @waba_id, @phone_number_id ].compact.all? { |id| id.to_s.match?(/\A\d+\z/) }

      app_token = "#{ENV.fetch('META_APP_ID')}|#{ENV.fetch('META_APP_SECRET')}"
      exchange = @client.get!("oauth/access_token?#{URI.encode_www_form(client_id: ENV.fetch('META_APP_ID'), client_secret: ENV.fetch('META_APP_SECRET'), code: @code)}", token: app_token)
      @token = exchange.fetch("access_token")
      raise ArgumentError, "Meta no devolvió credenciales." if @token.blank?

      details = @client.get!("debug_token?#{URI.encode_www_form(input_token: @token)}", token: app_token).fetch("data")
      validate_grant!(details)
      resolve_phone!
      phone = @client.get!("#{@phone_number_id}?fields=id,is_on_biz_app,platform_type", token: @token)
      unless phone["id"] == @phone_number_id && phone["is_on_biz_app"] == true && phone["platform_type"] == "CLOUD_API"
        raise ArgumentError, "La línea no está vinculada en coexistencia con WhatsApp Business. No se migró ni registró ningún número."
      end

      expiry = [ expiry_time(details["expires_at"]), (Time.current + exchange["expires_in"].to_i.seconds if exchange["expires_in"].to_i.positive?) ].compact.min || 60.days.from_now
      data_expiry = expiry_time(details["data_access_expires_at"])
      raise ArgumentError, "Las credenciales de Meta vencieron." if [ expiry, data_expiry ].compact.any? { |time| time <= Time.current }

      @business.with_lock do
        if WhatsAppConnection.where(phone_number_id: @phone_number_id).where.not(business_id: @business.id).exists?
          raise ArgumentError, "Esa línea ya está asociada a otra peluquería."
        end
        connection = @business.whatsapp_connection || @business.build_whatsapp_connection
        same_number = connection.persisted? && connection.phone_number_id == @phone_number_id && connection.waba_id == @waba_id
        sync_metadata = same_number && connection.sync_metadata["_offboarded_at"].blank? ? connection.sync_metadata : {}
        # The database unique index also protects simultaneous claims.
        connection.assign_attributes(phone_number_id: @phone_number_id, waba_id: @waba_id)
        connection.validate!
        result = @client.post!("#{@waba_id}/subscribed_apps", {}, token: @token)
        raise CloudClient::Error, "Meta no confirmó la suscripción." unless result["success"] == true

        connection.assign_attributes(access_token: @token, disconnected_at: nil, authorization_failed_at: nil,
          connected_at: Time.current, verified_at: Time.current, subscribed_at: Time.current,
          token_expires_at: expiry, data_access_expires_at: data_expiry, automation_enabled: false,
          templates_approved: false, sync_metadata: sync_metadata)
        connection.save!
        connection
      end
    end

    private
      def validate_grant!(details)
        unless details["is_valid"] == true && details["app_id"] == ENV.fetch("META_APP_ID") && (PERMISSIONS - Array(details["scopes"])).empty?
          raise ArgumentError, "Meta no otorgó los permisos necesarios a esta aplicación."
        end

        scopes = Array(details["granular_scopes"])
        granted = PERMISSIONS.map do |permission|
          Array(scopes.find { |scope| scope["scope"] == permission }&.fetch("target_ids", []))
        end.reduce { |left, right| left & right }
        @waba_id ||= granted.sole if granted.one?
        raise ArgumentError, "No se pudo identificar una única WABA autorizada. Volvé a conectar y seleccioná tu cuenta." unless @waba_id && granted.include?(@waba_id)
      end

      def resolve_phone!
        phones = []
        cursor = nil
        seen_cursors = []
        loop do
          path = "#{@waba_id}/phone_numbers?fields=id&limit=100"
          path += "&after=#{URI.encode_www_form_component(cursor)}" if cursor
          page = @client.get!(path, token: @token)
          phones.concat(page.fetch("data"))
          break if page.dig("paging", "next").blank?

          cursor = page.dig("paging", "cursors", "after")
          raise ArgumentError, "No se pudo completar la consulta de números." if cursor.blank? || seen_cursors.include?(cursor) || seen_cursors.length >= 50

          seen_cursors << cursor
        end
        @phone_number_id ||= phones.sole.fetch("id") if phones.one?
        unless @phone_number_id && phones.any? { |phone| phone["id"] == @phone_number_id }
          raise ArgumentError, "No se pudo identificar un único número de la WABA. Volvé a conectar y seleccioná tu línea."
        end
      end

      def expiry_time(value)
        Time.at(value.to_i).utc if value.to_i.positive?
      end
  end
end
