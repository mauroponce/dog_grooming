class DepositReceiptsController < ApplicationController
  allow_unauthenticated_access

  before_action :set_appointment

  def show
    @receipt_state = receipt_state
  end

  def update
    DepositProofs::ReplaceService.new(booking: @appointment, file: params[:deposit_receipt]).call
    redirect_to deposit_receipt_path(params[:token]), notice: "Recibimos tu comprobante. El turno queda pendiente de revisión."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to deposit_receipt_path(params[:token]), alert: error.record.errors.full_messages.to_sentence.presence || "No pudimos guardar el comprobante."
  end

  private
    def set_appointment
      @appointment = Appointment.find_signed!(params[:token], purpose: :deposit_upload)
      @business = @appointment.business
      redirect_to public_business_path(@business.slug), alert: "Este turno no acepta comprobantes." unless @appointment.manual_payment_required?
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "El link para subir el comprobante no es válido o venció."
    end

    def receipt_state
      return :closed if closed_booking?
      return :approved if @appointment.confirmed? || @appointment.deposit_status == "approved"
      return :replacement if replacement_requested? && replaceable_receipt?
      return :rejected if @appointment.deposit_rejected? || @appointment.deposit_status == "rejected"
      return :pending_review if @appointment.pending_deposit_review? && @appointment.deposit_receipt.attached?

      :empty
    end

    def replacement_requested?
      params[:replace].present?
    end

    def replaceable_receipt?
      @appointment.deposit_receipt.attached? && @appointment.pending_deposit_review?
    end

    def closed_booking?
      @appointment.canceled? || @appointment.expired? || @appointment.completed? || @appointment.no_show? || @appointment.rescheduled?
    end
end
