require "uri"

module MercadoPago
  class CreateBookingPreference
    def self.call(appointments:, host: AppUrl.host, protocol: AppUrl.protocol)
      new(appointments:, host:, protocol:).call
    end

    def initialize(appointments:, host: AppUrl.host, protocol: AppUrl.protocol)
      @appointments = Array(appointments).compact
      @business = @appointments.first&.business
      @callback_host = host.to_s.presence || AppUrl.host
      @callback_protocol = protocol.to_s.delete_suffix("://").presence || AppUrl.protocol
    end

    def call
      raise ArgumentError, "No hay turnos para cobrar." if appointments.blank?
      raise ArgumentError, "Los turnos no pertenecen al mismo negocio." unless appointments.all? { |appointment| appointment.business_id == business.id }
      raise ArgumentError, "Mercado Pago no está conectado para este negocio." unless connection&.connected?
      raise ArgumentError, "La cuenta de Mercado Pago está conectada en modo prueba. Reconectala desde Configuración para cobrar pagos reales." if connection.requires_production_reconnection?

      payment = AppointmentPayment.find_or_initialize_by(appointment: appointments.first, provider: "mercado_pago")
      payment.assign_attributes(
        business: business,
        status: "pending",
        amount_cents: amount_cents,
        currency: "ARS",
        metadata: metadata
      )
      payment.save!

      preference = MercadoPago::Client.for_connection(connection).create_preference!(preference_payload(payment))
      ensure_production_checkout!(preference)
      payment.update!(
        preference_id: preference["id"],
        init_point: preference["init_point"],
        sandbox_init_point: preference["sandbox_init_point"],
        raw_payload: preference
      )
      payment
    end

    private
      attr_reader :appointments, :business, :callback_host, :callback_protocol

      def connection
        @connection ||= business.mercado_pago_connection
      end

      def amount_cents
        @amount_cents ||= appointments.sum { |appointment| appointment.deposit_amount_cents.to_i }
      end

      def metadata
        {
          appointment_ids: appointments.map(&:id),
          business_id: business.id,
          primary_appointment_id: appointments.first.id,
          service_ids: appointments.map(&:service_id),
          customer_profile_id: appointments.first.customer_profile_id
        }.compact
      end

      def preference_payload(payment)
        {
          items: [
            {
              id: payment.external_reference,
              title: preference_title,
              description: preference_description,
              quantity: 1,
              currency_id: payment.currency,
              unit_price: amount_cents / 100.0
            }
          ],
          external_reference: payment.external_reference,
          metadata: metadata.merge(external_reference: payment.external_reference),
          payer: payer_payload,
          back_urls: back_urls,
          auto_return: "approved",
          notification_url: notification_url(payment)
        }.compact
      end

      def preference_title
        if appointments.one?
          "Reserva #{appointments.first.service.name} - #{business.name}"
        else
          "Reserva #{appointments.size} servicios - #{business.name}"
        end
      end

      def preference_description
        services = appointments.map { |appointment| appointment.service.name }.join(", ")
        "#{services} para #{appointments.first.customer_name}, #{appointments.first.customer_starts_at_label}"
      end

      def payer_payload
        appointment = appointments.first
        return if appointment.customer_email.blank?

        {
          name: appointment.customer_name,
          email: appointment.customer_email
        }
      end

      def back_urls
        token = appointments.first.signed_id(expires_in: 30.days, purpose: :public_booking_confirmation)
        {
          success: booking_return_url(token, "success"),
          pending: booking_return_url(token, "pending"),
          failure: booking_return_url(token, "failure")
        }
      end

      def booking_return_url(token, status)
        business = appointments.first.business
        PublicUrls.url(
          :business,
          business,
          confirmation: token,
          mp_status: status,
          host: callback_host,
          protocol: callback_protocol,
          use_custom_domain: Business.normalize_custom_domain(callback_host) == business.custom_domain
        )
      end

      def notification_url(payment)
        business = appointments.first.business
        host = callback_host
        protocol = callback_protocol
        if Business.normalize_custom_domain(callback_host) == business.custom_domain
          host = AppUrl.host
          protocol = AppUrl.protocol
        end

        return if host.include?("localhost") || host.include?("127.0.0.1")

        Rails.application.routes.url_helpers.webhooks_mercado_pago_url(
          reference: payment.external_reference,
          host: host,
          protocol: protocol
        )
      end

      def ensure_production_checkout!(preference)
        return if Credentials.test?

        host = URI.parse(preference["init_point"].to_s).host.to_s.downcase
        return if preference["init_point"].present? && host.present? && !host.start_with?("sandbox.")

        raise ArgumentError, "Mercado Pago no devolvió un checkout productivo. Reconectá la cuenta de cobro e intentá nuevamente."
      rescue URI::InvalidURIError
        raise ArgumentError, "Mercado Pago no devolvió un checkout productivo. Reconectá la cuenta de cobro e intentá nuevamente."
      end
  end
end
