class DepositReviewsController < ApplicationController
  allow_unauthenticated_access

  before_action :set_appointment

  def show
    @business = @appointment.business
    @confirm_whatsapp_url = @appointment.deposit_confirmation_whatsapp_url
    @reject_whatsapp_url = @appointment.deposit_rejection_whatsapp_url(reason: @appointment.deposit_rejection_reason)
  end

  def confirm
    redirect_to deposit_review_path(params[:token]), alert: "No se puede confirmar un turno cancelado." and return if @appointment.canceled?

    DepositProofs::ApproveService.new(appointment: @appointment, actor: @appointment.business.owner).call
    redirect_to deposit_review_path(params[:token]), notice: "Turno confirmado. Ahora podés avisarle al cliente por WhatsApp."
  end

  def reject
    redirect_to deposit_review_path(params[:token]), alert: "No se puede rechazar un turno confirmado o cancelado." and return if @appointment.confirmed? || @appointment.canceled?

    reason = params[:reason].presence || "Comprobante no validado por el centro."
    DepositProofs::RejectService.new(appointment: @appointment, actor: @appointment.business.owner, reason: reason).call
    redirect_to deposit_review_path(params[:token]), notice: "Comprobante rechazado. Ahora podés pedirle al cliente que reintente el pago por WhatsApp."
  rescue StandardError => error
    redirect_to deposit_review_path(params[:token]), alert: error.message
  end

  private
    def set_appointment
      @appointment = Appointment.find_by(deposit_review_token: params[:token]) || Appointment.find_signed!(params[:token], purpose: :deposit_review)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "El link de revisión no es válido o venció."
    end

end
