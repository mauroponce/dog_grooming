module ApplicationHelper
  SUBSCRIPTION_STATUS_LABELS = {
    "active" => "Activa",
    "authorized" => "Activa",
    "trialing" => "En prueba",
    "payment_due" => "Pago pendiente",
    "pending_review" => "Pago en revisión",
    "overdue" => "Pago vencido",
    "restricted" => "Restringida",
    "pending" => "Pendiente",
    "payment_pending" => "Pago pendiente",
    "payment_under_review" => "Pago en revisión",
    "past_due" => "Pago vencido",
    "suspended" => "Suspendida",
    "canceled" => "Cancelada",
    "cancelled" => "Cancelada",
    "expired" => "Vencida",
    "failed" => "Fallida"
  }.freeze

  EMPLOYEE_STATUS_LABELS = {
    "active" => "Activo",
    "pending" => "Pendiente",
    "revoked" => "Revocado"
  }.freeze

  CLIENT_NOTE_TYPE_LABELS = {
    "general" => "General",
    "clinical" => "Clínica",
    "technical" => "Técnica"
  }.freeze

  BOOKING_NOTE_TYPE_LABELS = {
    "post_appointment" => "Post-turno",
    "no_show" => "No asistió",
    "cancellation" => "Cancelación",
    "follow_up" => "Seguimiento",
    "reschedule" => "Reprogramación"
  }.freeze

  def format_ar_date(value)
    CustomerDateFormatter.date_label(value)
  end

  def format_ar_datetime(value)
    CustomerDateFormatter.datetime_label(value)
  end

  def format_ar_time(value)
    CustomerDateFormatter.time_label(value)
  end

  def appointment_status_label(appointment_or_status)
    status = appointment_or_status.respond_to?(:status) ? appointment_or_status.status : appointment_or_status.to_s
    Appointment.status_label(status)
  end

  def appointment_status_full_label(appointment_or_status)
    status = appointment_or_status.respond_to?(:status) ? appointment_or_status.status : appointment_or_status.to_s
    Appointment.status_full_label(status)
  end

  def appointment_source_label(appointment_or_source)
    source = appointment_or_source.respond_to?(:source) ? appointment_or_source.source : appointment_or_source.to_s
    Appointment.source_label(source)
  end

  def appointment_deposit_status_label(appointment_or_status)
    status = appointment_or_status.respond_to?(:deposit_status) ? appointment_or_status.deposit_status : appointment_or_status.to_s
    Appointment.deposit_status_label(status)
  end

  def current_public_business_url(business)
    PublicUrls.url(
      :business,
      business,
      host: current_public_link_host,
      protocol: current_public_link_protocol
    )
  end

  def current_public_service_url(service)
    PublicUrls.url(
      :short_service,
      service.business,
      service.slug,
      host: current_public_link_host,
      protocol: current_public_link_protocol
    )
  end

  def display_public_url(url)
    url.to_s
  end

  def current_public_link_host
    forwarded_host = request&.headers&.fetch("X-Forwarded-Host", nil).to_s.split(",").first&.strip
    forwarded_host.presence || request&.host_with_port.presence || AppUrl.host
  end

  def current_public_link_protocol
    forwarded_protocol = request&.headers&.fetch("X-Forwarded-Proto", nil).to_s.split(",").first&.strip
    protocol = forwarded_protocol.presence || request&.protocol.presence || AppUrl.protocol

    "#{protocol.to_s.delete_suffix("://")}://"
  end

  def subscription_status_label(status)
    label_for(status, SUBSCRIPTION_STATUS_LABELS)
  end

  def employee_status_label(status)
    label_for(status, EMPLOYEE_STATUS_LABELS)
  end

  def client_note_type_label(note_type)
    label_for(note_type, CLIENT_NOTE_TYPE_LABELS)
  end

  def booking_note_type_label(note_type)
    label_for(note_type, BOOKING_NOTE_TYPE_LABELS)
  end

  private
    def label_for(value, labels)
      value = value.to_s
      labels.fetch(value, value.tr("_", " ").capitalize)
    end
end
