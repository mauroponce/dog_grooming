module Ai
  class ChatTools
    FUNCTIONS = [
      {
        type: "function",
        name: "get_services_catalog",
        description: "Retorna el listado de servicios del comercio actual con precios y duraciones.",
        parameters: {
          type: "object",
          properties: {}
        }
      },
      {
        type: "function",
        name: "check_availability",
        description: "Verifica si un servicio del comercio actual tiene un horario disponible en una fecha y hora exactas. No usar para pedidos flexibles como 'cualquier dia', 'por la manana' o 'mediados de mes'.",
        parameters: {
          type: "object",
          properties: {
            service_id: { type: "integer", description: "ID del servicio del comercio actual." },
            date: { type: "string", description: "Fecha en formato YYYY-MM-DD." },
            time: { type: "string", description: "Hora local en formato HH:MM." }
          },
          required: [ "service_id", "date", "time" ]
        }
      },
      {
        type: "function",
        name: "find_available_slots",
        description: "Busca horarios realmente disponibles para un servicio dentro de un rango de fechas y una franja horaria flexible. Usar para pedidos como 'cualquier dia por la manana', 'mediados de julio', 'esta semana' o 'la semana que viene'.",
        parameters: {
          type: "object",
          properties: {
            service_id: { type: "integer", description: "ID del servicio del comercio actual." },
            start_date: { type: "string", description: "Fecha inicial en formato YYYY-MM-DD. Si falta, usar hoy." },
            end_date: { type: "string", description: "Fecha final en formato YYYY-MM-DD. Si falta, buscar durante los proximos 14 dias." },
            period: {
              type: "string",
              enum: [ "morning", "afternoon", "evening", "any" ],
              description: "Franja solicitada: morning 06:00-11:59, afternoon 12:00-17:59, evening 18:00-23:59, any todo el dia."
            },
            limit: { type: "integer", description: "Cantidad maxima de horarios a devolver. Usar 3 a 5." }
          },
          required: [ "service_id" ]
        }
      },
      {
        type: "function",
        name: "find_appointment_by_contact",
        description: "Busca turnos futuros del comercio actual asociados a un correo o número de teléfono.",
        parameters: {
          type: "object",
          properties: {
            contact_info: { type: "string", description: "Correo o teléfono informado por el cliente." }
          },
          required: [ "contact_info" ]
        }
      },
      {
        type: "function",
        name: "generate_booking_or_deposit_link",
        description: "Crea una reserva pendiente para el comercio actual y retorna link de carga de comprobante si requiere seña.",
        parameters: {
          type: "object",
          properties: {
            service_id: { type: "integer", description: "ID del servicio del comercio actual." },
            start_time: { type: "string", description: "Fecha y hora local o ISO8601 del turno." },
            client_name: { type: "string", description: "Nombre del cliente." },
            client_phone: { type: "string", description: "Teléfono del cliente." }
          },
          required: [ "service_id", "start_time", "client_name", "client_phone" ]
        }
      }
    ].freeze

    def initialize(business:)
      @business = business
    end

    def declarations
      FUNCTIONS
    end

    def call(name, arguments)
      public_send(name, **normalized_arguments(arguments))
    rescue NoMethodError
      failure(name:, message: "Herramienta no permitida.")
    rescue ArgumentError => error
      failure(name:, message: error.message)
    end

    def get_services_catalog
      services = business.services.publicly_bookable.includes(:service_tags).order(:category, :name).map do |service|
        {
          id: service.id,
          name: service.name,
          category: service.category_label,
          duration_minutes: service.duration_minutes,
          price_cents: service.price_cents,
          price_label: service.display_price,
          deposit_required: service.deposit_required?,
          deposit_summary: service.deposit_summary,
          search_terms: service.service_tags.map(&:name),
          booking_url: PublicUrls.url(
            :booking,
            business,
            service_id: service.slug,
            date: Time.zone.today,
            host: app_host,
            protocol: app_protocol
          )
        }
      end

      {
        ok: true,
        tool: "get_services_catalog",
        answer: services.any? ? "Estos son los servicios disponibles." : "Todavía no hay servicios publicados.",
        component: {
          type: "services_catalog",
          services: services
        }
      }
    end

    def check_availability(service_id:, date:, time:)
      service = business.services.publicly_bookable.find_by(id: service_id)
      return failure(name: "check_availability", message: "No encontré ese servicio en este negocio.") unless service

      starts_at = parse_local_datetime(date:, time:)
      available = Availability::Slots.public_available?(business: business, service: service, starts_at: starts_at)
      {
        ok: true,
        tool: "check_availability",
        answer: available ? "Ese horario está disponible." : "Ese horario no está disponible.",
        component: {
          type: "availability_result",
          available: available,
          service: service_payload(service),
          starts_at: starts_at.iso8601,
          date_label: CustomerDateFormatter.appointment_label(starts_at),
            booking_url: PublicUrls.url(
              :booking,
              business,
              service_id: service.slug,
              date: starts_at.to_date,
              host: app_host,
            protocol: app_protocol
          )
        }
      }
    rescue Date::Error, ArgumentError
      failure(name: "check_availability", message: "Necesito una fecha YYYY-MM-DD y una hora HH:MM válidas.")
    end

    def find_available_slots(service_id:, start_date: nil, end_date: nil, period: "any", limit: 5)
      service = business.services.publicly_bookable.find_by(id: service_id)
      return failure(name: "find_available_slots", message: "No encontré ese servicio en este negocio.") unless service

      start_on, end_on = normalized_date_range(start_date, end_date)
      normalized_period = normalize_period(period)
      max_results = limit.to_i.clamp(1, 6)
      slots = available_slot_payloads(service:, start_on:, end_on:, period: normalized_period, limit: max_results)
      answer = if slots.any?
        count_label = slots.one? ? "este horario disponible" : "estos horarios disponibles"
        "Encontré #{count_label} para #{service.name} #{period_label(normalized_period)}."
      else
        "No encontré horarios disponibles para #{service.name} #{period_label(normalized_period)} en ese rango."
      end

      {
        ok: true,
        tool: "find_available_slots",
        answer: answer.squish,
        component: {
          type: "available_slots",
          available: slots.any?,
          service: service_payload(service),
          period: normalized_period,
          period_label: period_label(normalized_period).strip,
          searched_range_label: searched_range_label(start_on, end_on),
          slots: slots
        }
      }
    rescue Date::Error, ArgumentError
      failure(name: "find_available_slots", message: "Necesito fechas válidas en formato YYYY-MM-DD.")
    end

    def find_appointment_by_contact(contact_info:)
      contact = contact_info.to_s.strip
      normalized_phone = PhoneNumber.normalize(contact)
      appointments = business.appointments
        .active
        .includes(:service)
        .where("starts_at >= ?", Time.current)
        .where("customer_email = :contact OR customer_phone = :contact OR customer_phone = :phone", contact: contact, phone: normalized_phone)
        .order(:starts_at)
        .limit(5)

      {
        ok: true,
        tool: "find_appointment_by_contact",
        answer: appointments.any? ? "Encontré estos turnos futuros." : "No encontré turnos futuros con ese contacto.",
        component: {
          type: "appointments_list",
          appointments: appointments.map { |appointment| appointment_payload(appointment) }
        }
      }
    end

    def generate_booking_or_deposit_link(service_id:, start_time:, client_name:, client_phone:)
      service = business.services.publicly_bookable.find_by(id: service_id)
      return failure(name: "generate_booking_or_deposit_link", message: "No encontré ese servicio en este negocio.") unless service

      starts_at = parse_start_time(start_time)
      appointment = Appointments::CreateBooking.call(
        business: business,
        service: service,
        starts_at: starts_at,
        customer_name: client_name,
        customer_phone: client_phone,
        payment_method: "manual_transfer"
      )

      if appointment.deposit_pending?
        link = appointment.deposit_upload_url
        link_type = "deposit"
        answer = "Te dejo el enlace para subir el comprobante de la seña. El centro lo revisará antes de confirmar el turno."
      else
        link = appointment.customer_portal_booking_url
        link_type = "confirmed"
        answer = "La solicitud quedó enviada. Podés consultar el estado de tu turno desde este enlace."
      end

      {
        ok: true,
        tool: "generate_booking_or_deposit_link",
        answer: answer,
        component: {
          type: "booking_link",
          link_type: link_type,
          url: link,
          appointment: appointment_payload(appointment),
          service: service_payload(service)
        }
      }
    rescue Appointments::BlockedCustomer, Appointments::UnavailableSlot, ActiveRecord::RecordInvalid, ArgumentError, TypeError => error
      failure(name: "generate_booking_or_deposit_link", message: error.message)
    end

    private
      attr_reader :business

      def normalized_arguments(arguments)
        (arguments || {}).to_h.transform_keys(&:to_sym)
      end

      def parse_local_datetime(date:, time:)
        Date.iso8601(date.to_s)
        Time.zone.parse("#{date} #{time}").tap do |value|
          raise ArgumentError, "Fecha u hora inválida" if value.blank?
        end
      end

      def parse_start_time(value)
        Time.zone.parse(value.to_s).tap do |time|
          raise ArgumentError, "Fecha y hora inválida" if time.blank?
        end
      end

      def normalized_date_range(start_date, end_date)
        today = Time.zone.today
        horizon = Availability::AvailableSlots::HORIZON.from_now.to_date
        start_on = parse_optional_date(start_date) || today
        start_on = today if start_on < today
        start_on = horizon if start_on > horizon

        end_on = parse_optional_date(end_date) || (start_on + 14.days)
        end_on = start_on if end_on < start_on
        end_on = [ end_on, start_on + 21.days, horizon ].min

        [ start_on, end_on ]
      end

      def parse_optional_date(value)
        return if value.blank?

        Date.iso8601(value.to_s)
      end

      def normalize_period(value)
        value.to_s.in?(%w[morning afternoon evening any]) ? value.to_s : "any"
      end

      def period_label(period)
        {
          "morning" => "por la mañana",
          "afternoon" => "por la tarde",
          "evening" => "por la noche",
          "any" => ""
        }.fetch(period, "")
      end

      def period_hours(period)
        {
          "morning" => 6...12,
          "afternoon" => 12...18,
          "evening" => 18...24,
          "any" => 0...24
        }.fetch(period, 0...24)
      end

      def available_slot_payloads(service:, start_on:, end_on:, period:, limit:)
        slots = []
        hours = period_hours(period)

        (start_on..end_on).each do |date|
          Availability::Slots.public_records_for(business: business, service: service, date: date).each do |slot|
            next unless hours.cover?(slot.starts_at.in_time_zone.hour)

            slots << slot_payload(slot, service)
            return slots if slots.size >= limit
          end
        end

        slots
      end

      def slot_payload(slot, service)
        employee_membership = slot.employee_membership
        {
          service_id: service.id,
          service_name: service.name,
          starts_at: slot.starts_at.iso8601,
          starts_at_label: CustomerDateFormatter.datetime_label(slot.starts_at),
          date_label: CustomerDateFormatter.date_label(slot.starts_at),
          time_label: CustomerDateFormatter.time_label(slot.starts_at),
          employee_membership_id: employee_membership&.id,
          employee_membership_name: employee_membership&.name,
          booking_url: PublicUrls.url(
            :booking,
            business,
            service_id: service.slug,
            date: slot.starts_at.to_date,
            employee_membership_id: employee_membership&.id,
            host: app_host,
            protocol: app_protocol
          )
        }
      end

      def searched_range_label(start_on, end_on)
        return CustomerDateFormatter.date_label(start_on.in_time_zone) if start_on == end_on

        "#{CustomerDateFormatter.date_label(start_on.in_time_zone)} al #{CustomerDateFormatter.date_label(end_on.in_time_zone)}"
      end

      def service_payload(service)
        {
          id: service.id,
          name: service.name,
          category: service.category_label,
          duration_minutes: service.duration_minutes,
          price_cents: service.price_cents,
          price_label: service.display_price
        }
      end

      def appointment_payload(appointment)
        {
          id: appointment.short_uuid,
          service_id: appointment.service_id,
          service_name: appointment.service.name,
          customer_name: appointment.customer_name,
          starts_at: appointment.starts_at.iso8601,
          starts_at_label: CustomerDateFormatter.datetime_label(appointment.starts_at),
          status: appointment.status_label,
          deposit_status: appointment.deposit_status_label,
          action_url: appointment.manual_confirmation_url
        }
      end

      def failure(name:, message:)
        {
          ok: false,
          tool: name,
          answer: message,
          component: {
            type: "tool_error",
            message: message
          }
        }
      end

      def app_host
        AppUrl.host
      end

      def app_protocol
        AppUrl.protocol
      end
  end
end
