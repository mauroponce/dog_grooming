module PlatformMercadoPago
  class SyncSubscription
    def self.call(subscription)
      return unless subscription.mercado_pago? && subscription.provider_subscription_id.present?

      payload = Client.new.fetch_subscription!(subscription.provider_subscription_id)
      return unless payload["id"].to_s == subscription.provider_subscription_id &&
        payload["external_reference"].to_s == subscription.external_reference

      status = payload["status"].to_s
      attributes = { provider_status: status, raw_payload: subscription.raw_payload.to_h.merge(payload) }
      case status
      when "authorized"
        attributes.merge!(status: "payment_due", subscribed_at: subscription.subscribed_at || Time.current,
          suspended_at: nil, cancelled_at: nil)
      when "paused"
        attributes.merge!(status: "suspended", suspended_at: Time.current)
      when "cancelled", "canceled"
        attributes.merge!(status: "cancelled", cancelled_at: Time.current)
      else
        attributes[:status] = "payment_due"
      end
      subscription.update!(attributes)
      if status == "authorized"
        invoices = Client.new.search_authorized_payments!(subscription.provider_subscription_id).fetch("results", [])
        invoices.each { |invoice| ApplyAuthorizedPayment.call(invoice) }
        subscription.update!(status: subscription.active? ? "active" : "payment_due")
      end
    end
  end
end
