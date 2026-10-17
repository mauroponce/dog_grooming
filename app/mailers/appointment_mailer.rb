class AppointmentMailer < ApplicationMailer
  def customer_reminder(appointment)
    @appointment = appointment
    @business = appointment.business
    @google_calendar_url = appointment.google_calendar_url
    @booking_url = public_booking_url(appointment.business.slug, confirmation: appointment.public_confirmation_token, host: app_host, protocol: app_protocol)
    mail subject: "Recordatorio de tu turno en #{@business.name}", to: appointment.customer_email
  end

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
end
