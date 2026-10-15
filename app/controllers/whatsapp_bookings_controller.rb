class WhatsAppBookingsController < ApplicationController
  allow_unauthenticated_access

  def show
    intent = BookingIntent.find_signed(params[:token], purpose: :whatsapp_booking)
    return head :not_found unless intent && intent.expires_at.future? && BookingIntent.active.exists?(id: intent.id)
    return head :not_found unless intent.business.booking_available? && intent.business.services.publicly_bookable.exists?(id: intent.service_id)

    session[:whatsapp_booking_intent_id] = intent.id
    response.headers["Referrer-Policy"] = "no-referrer"
    redirect_to new_public_booking_path(intent.business.slug, service_id: intent.service.slug, step: "schedule")
  end
end
