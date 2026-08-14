module WhatsApp
  class MessageBuilder
    CUSTOMER_PORTAL_TEMPLATE_KEYS = %w[
      booking_confirmation
      deposit_request
      proof_request
      proof_rejected
      appointment_reminder
      booking_reschedule
      booking_cancelled
    ].freeze

    def initialize(business:, template_key:, booking: nil, customer: nil, service: nil, professional: nil, gap: nil, waitlist_entry: nil, campaign_link: nil, customer_pack: nil, gift_card: nil)
      @business = business
      @template_key = template_key.to_s
      @booking = booking
      @customer = customer || booking&.customer_profile
      @service = service || booking&.service || waitlist_entry&.service
      @professional = professional || booking&.employee_membership
      @gap = gap
      @waitlist_entry = waitlist_entry
      @campaign_link = campaign_link
      @customer_pack = customer_pack
      @gift_card = gift_card
    end

    def message
      return "" if template&.active? == false
      return booking_confirmation_message if template_key == "booking_confirmation" && booking.present?

      body = template_body.gsub(/\{\{([a-z_]+)\}\}/) { value_for(Regexp.last_match(1)) }
      append_customer_portal_link(body)
    end

    def url(phone: nil)
      return "" if message.blank?

      WhatsApp::UrlBuilder.call(phone: phone.presence || default_phone, text: message)
    rescue WhatsApp::UrlBuilder::MissingPhone
      ""
    end

    private
      attr_reader :business, :template_key, :booking, :customer, :service, :professional, :gap, :waitlist_entry, :campaign_link, :customer_pack, :gift_card

      def template_body
        template&.body.presence || WhatsAppTemplate::DEFAULTS.dig(template_key, :body).to_s
      end

      def template
        @template ||= begin
          WhatsAppTemplate.ensure_defaults_for!(business) if business.whatsapp_templates.loaded? || business.whatsapp_templates.exists?
          business.whatsapp_templates.find_by(key: template_key)
        end
      end

      def value_for(variable)
        values.fetch(variable, "")
      end

      def values
        @values ||= {
          "customer_name" => customer_name,
          "business_name" => business.name,
          "service_name" => service&.name.to_s,
          "booking_date" => booking&.starts_at.present? ? CustomerDateFormatter.date_label(booking.starts_at) : "",
          "booking_time" => booking&.starts_at.present? ? CustomerDateFormatter.time_label(booking.starts_at) : "",
          "professional_name" => professional&.name.to_s,
          "deposit_amount" => booking&.formatted_deposit_amount.to_s,
          "payment_alias" => service&.deposit_payment_reference.presence || business.deposit_alias.presence || business.deposit_account.presence || business.deposit_payment_link.presence || "los datos de seña del centro",
          "public_booking_link" => business.public_url,
          "service_link" => service_link,
          "campaign_link" => campaign_link&.tracked_url.to_s,
          "pack_name" => customer_pack&.service_pack&.name.to_s,
          "remaining_sessions" => customer_pack&.remaining_sessions.to_s,
          "gift_card_code" => gift_card&.code.to_s,
          "booking_link" => booking_link,
          "customer_portal_link" => customer_portal_link,
          "business_whatsapp" => business.public_phone.to_s,
          "address" => business.public_location.to_s,
          "gap_date" => gap_time.present? ? CustomerDateFormatter.date_label(gap_time) : "",
          "gap_time" => gap_time.present? ? CustomerDateFormatter.time_label(gap_time) : ""
        }
      end

      def customer_name
        customer&.name.presence || booking&.customer_name.presence || waitlist_entry&.client_name.presence || "clienta"
      end

      def booking_link
        return booking.deposit_upload_url if booking&.deposit_required? && !booking&.confirmed?
        return booking.manual_confirmation_url if booking.present?

        business.public_url
      end

      def customer_portal_link
        booking&.customer_portal_profile_url.presence || customer&.customer_portal_url.to_s
      end

      def booking_confirmation_message
        date_and_time = booking.starts_at.in_time_zone.strftime("%d/%m/%Y, %H:%Mhs")

        [
          "Hola #{customer_name},",
          "✅ Turno confirmado con #{business.name}",
          "Servicio: #{service&.name}",
          "Fecha y hora: #{date_and_time}",
          "Podes gestionar tus turnos aca: #{customer_portal_link}"
        ].join("\n")
      end

      def append_customer_portal_link(body)
        return body unless CUSTOMER_PORTAL_TEMPLATE_KEYS.include?(template_key)
        return body if customer_portal_link.blank? || body.include?(customer_portal_link)

        [
          body.to_s.rstrip,
          "",
          "También podés ver, cancelar o reprogramar tus turnos acá: #{customer_portal_link}"
        ].join("\n")
      end

      def service_link
        return "" if service.blank?

        service.public_service_url.presence ||
          PublicUrls.url(
            :booking,
            business,
            service_id: service.slug,
            date: Time.zone.today
          )
      end

      def gap_time
        if gap.respond_to?(:starts_at)
          gap.starts_at
        elsif waitlist_entry&.released_starts_at.present?
          waitlist_entry.released_starts_at
        end
      end

      def default_phone
        customer&.phone.presence || booking&.customer_phone.presence || waitlist_entry&.client_phone
      end
  end
end
