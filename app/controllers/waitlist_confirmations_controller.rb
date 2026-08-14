class WaitlistConfirmationsController < ApplicationController
  allow_unauthenticated_access

  before_action :set_entry

  def show
    @appointment = @entry.released_appointment
  end

  def confirm
    @appointment = @entry.released_appointment
    claim_released_appointment!
    redirect_to waitlist_confirmation_path(params[:token]), notice: "El turno quedó confirmado a tu nombre."
  rescue StandardError => error
    redirect_to waitlist_confirmation_path(params[:token]), alert: error.message
  end

  private
    def set_entry
      @entry = WaitlistEntry.find_signed!(params[:token], purpose: :waitlist_confirmation)
      raise ActiveRecord::RecordNotFound if @entry.token_seguro != params[:token]
      raise ActiveRecord::RecordNotFound if @entry.expired_notification?
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "El enlace de lista de espera no es válido o venció."
    end

    def claim_released_appointment!
      raise "Este aviso ya no está disponible." unless @entry.offered?
      raise "El turno ya fue tomado." unless @appointment&.canceled?

      @appointment.business.with_lock do
        @appointment.reload
        raise "El turno ya fue tomado." unless @appointment.canceled?

        profile = find_or_update_customer_profile!
        @appointment.update!(
          customer_profile: profile,
          customer_name: @entry.client_name,
          customer_phone: @entry.client_phone,
          customer_email: @entry.email,
          status: :confirmed,
          confirmed_at: Time.current,
          canceled_at: nil,
          canceled_by: nil,
          cancellation_reason: nil,
          canceled_late: false,
          waitlist_entry: @entry
        )
        @entry.update!(status: "booked", accepted_at: Time.current)
        expire_competing_entries!
      end
    end

    def find_or_update_customer_profile!
      Customers::UpsertProfile.call(
        business: @appointment.business,
        name: @entry.client_name,
        phone: @entry.client_phone,
        email: @entry.email
      )
    end

    def expire_competing_entries!
      WaitlistEntry.where(
        center_id: @entry.center_id,
        service_id: @entry.service_id,
        desired_date: @entry.desired_date,
        released_appointment_id: @entry.released_appointment_id,
        status: "offered"
      ).where.not(id: @entry.id).update_all(status: "expired", updated_at: Time.current)
    end
end
