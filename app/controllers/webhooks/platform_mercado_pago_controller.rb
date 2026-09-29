module Webhooks
  class PlatformMercadoPagoController < ApplicationController
    allow_unauthenticated_access
    skip_before_action :verify_authenticity_token

    def create
      secret = ENV["PLATFORM_MERCADO_PAGO_WEBHOOK_SECRET"].to_s
      return head :unauthorized if secret.blank?
      return head :unauthorized unless MercadoPago::WebhookSignature.valid?(
        headers: request.headers, params: params.to_unsafe_h.except("controller", "action"), secret: secret
      )

      event_type = params[:type].presence || params[:topic].presence || request.request_parameters["type"]
      subscription_id = params.dig(:data, :id).presence || params["data.id"].presence || request.request_parameters.dig("data", "id")
      if event_type.to_s == "subscription_preapproval" && subscription_id.present?
        PlatformMercadoPago::SyncSubscriptionJob.perform_later(subscription_id.to_s)
      elsif event_type.to_s == "subscription_authorized_payment" && subscription_id.present?
        PlatformMercadoPago::SyncAuthorizedPaymentJob.perform_later(subscription_id.to_s)
      end
      head :ok
    end
  end
end
