class AppointmentMailer < ApplicationMailer
  def new_booking(appointment)
    @appointment = appointment
    @business = appointment.business
    @admin_calendar_url = admin_appointment_url(appointment, host: app_host, protocol: app_protocol)

    mail subject: "Nueva reserva para revisar", to: @business.owner.email_address
  end

  def deposit_receipt_submitted(appointment)
    @appointment = appointment
    @business = appointment.business
    @deposit_review_url = appointment.deposit_review_url

    mail subject: "Nuevo comprobante de seña para revisar", to: @business.owner.email_address
  end

  def customer_booking_received(appointment)
    return if appointment.customer_email.blank?

    @appointment = appointment
    @business = appointment.business
    @booking_url = appointment.customer_portal_booking_url
    @deposit_upload_url = appointment.deposit_upload_url if appointment.manual_payment_required? && !appointment.deposit_submitted?

    mail subject: "Recibimos tu solicitud de turno", to: appointment.customer_email
  end

  def customer_booking_confirmed(appointment)
    return if appointment.customer_email.blank?

    @appointment = appointment
    @business = appointment.business
    @booking_url = appointment.customer_portal_booking_url
    @google_calendar_url = appointment.google_calendar_url

    mail subject: "Tu turno en #{@business.name} está confirmado", to: appointment.customer_email
  end

  def customer_booking_cancelled(appointment)
    return if appointment.customer_email.blank?

    @appointment = appointment
    @business = appointment.business
    @cancelled_by_business = !Appointment::CUSTOMER_CANCELLATION_ACTORS.include?(appointment.canceled_by.to_s)

    mail subject: "Tu turno en #{@business.name} fue cancelado", to: appointment.customer_email
  end

  def customer_reminder(appointment)
    return if appointment.customer_email.blank?

    @appointment = appointment
    @business = appointment.business
    @booking_url = appointment.customer_portal_booking_url
    @google_calendar_url = appointment.google_calendar_url

    mail subject: "Recordatorio: tu turno en #{@business.name} es mañana", to: appointment.customer_email
  end

end
