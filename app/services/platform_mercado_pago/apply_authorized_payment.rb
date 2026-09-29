module PlatformMercadoPago
  class ApplyAuthorizedPayment
    def self.call(payload)
      subscription = Subscription.find_by(provider: "mercado_pago", provider_subscription_id: payload["preapproval_id"].to_s)
      return unless subscription
      return unless payload.dig("payment", "status") == "approved"

      debit_date = Time.zone.parse(payload["debit_date"].to_s)&.to_date
      return unless debit_date

      paid_until = debit_date.advance(months: 1)
      return if subscription.paid_until.present? && subscription.paid_until >= paid_until

      subscription.update!(paid_until: paid_until, last_payment_at: Time.current,
        status: subscription.provider_status == "authorized" ? "active" : subscription.status)
    rescue ArgumentError
      nil
    end
  end
end
