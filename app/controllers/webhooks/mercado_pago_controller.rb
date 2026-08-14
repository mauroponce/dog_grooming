module Webhooks
  class MercadoPagoController < ApplicationController
    allow_unauthenticated_access
    skip_before_action :verify_authenticity_token

    def create
      unless MercadoPago::WebhookSignature.valid?(headers: request.headers, params: webhook_params)
        head :unauthorized
        return
      end

      MercadoPago::ProcessWebhookJob.perform_later(
        payload: webhook_payload,
        headers: {
          "x-signature" => request.headers["x-signature"],
          "x-request-id" => request.headers["x-request-id"]
        },
        params: webhook_params
      )
      head :ok
    end

    private
      def webhook_payload
        @webhook_payload ||= request.request_parameters.presence || JSON.parse(request.raw_post.presence || "{}")
      rescue JSON::ParserError
        {}
      end

      def webhook_params
        @webhook_params ||= params.to_unsafe_h.except("controller", "action")
      end
  end
end
