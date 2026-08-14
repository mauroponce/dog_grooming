class AppointmentActionsController < ApplicationController
  allow_unauthenticated_access

  before_action :set_appointment

  def show
  end

  def confirm
    @appointment.confirm! unless @appointment.canceled?
    redirect_to appointment_action_path(params[:token]), notice: "Turno confirmado."
  end

  def cancel
    @appointment.cancel!(by: "customer_link", reason: "Cancelado desde enlace de confirmación")
    redirect_to appointment_action_path(params[:token]), notice: "Turno cancelado."
  end

  private
    def set_appointment
      @appointment = Appointment.find_signed!(params[:token], purpose: :appointment_customer_action)
      @business = @appointment.business
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "El enlace de confirmación no es válido o venció."
    end
end
