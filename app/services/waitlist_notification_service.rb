class WaitlistNotificationService
  LIMIT = 3

  def self.call(appointment)
    new(appointment).call
  end

  def initialize(appointment)
    @appointment = appointment
  end

  def call
    return [] unless appointment.canceled?

    entries = matching_entries.first(LIMIT)
    return [] if entries.blank?

    notified_entries = entries.map { |entry| notify_entry!(entry) }
    create_provider_event!(notified_entries)
    notified_entries
  end

  private
    attr_reader :appointment

    def matching_entries
      appointment.business.waitlist_entries.pending
        .where(service_id: appointment.service_id, desired_date: appointment.starts_at.to_date)
        .order(:created_at)
        .to_a
        .select { |entry| entry.matches_released_slot?(appointment.starts_at) }
    end

    def notify_entry!(entry)
      token = entry.notification_token
      entry.update!(
        status: "offered",
        token_seguro: token,
        released_appointment_id: appointment.id,
        released_starts_at: appointment.starts_at,
        offered_at: Time.current,
        notified_at: Time.current,
        expires_at: 15.minutes.from_now
      )
      entry
    end

    def create_provider_event!(entries)
      appointment.business.provider_events.create!(
        event_type: "waitlist_released_slot",
        title: "Lista de espera: turno liberado",
        body: "Se liberó #{appointment.service.name} el #{CustomerDateFormatter.datetime_label(appointment.starts_at)}. Enviá los enlaces 1-click a las primeras #{entries.size} personas.",
        metadata: {
          appointment_id: appointment.id,
          service_id: appointment.service_id,
          desired_date: appointment.starts_at.to_date.iso8601,
          start_time: appointment.starts_at.strftime("%H:%M"),
          action_url: admin_waitlist_url,
          waitlist_entry_ids: entries.map(&:id),
          links: entries.map { |entry| { name: entry.client_name, phone: entry.client_phone, whatsapp_url: entry.whatsapp_url } }
        }
      )
    end

    def admin_waitlist_url
      Rails.application.routes.url_helpers.admin_calendar_url(
        waitlist: "1",
        service_id: appointment.service_id,
        desired_date: appointment.starts_at.to_date.iso8601,
        start_time: appointment.starts_at.strftime("%H:%M"),
        host: AppUrl.host,
        protocol: AppUrl.protocol
      )
    end
end
