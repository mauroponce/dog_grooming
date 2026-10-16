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
end
