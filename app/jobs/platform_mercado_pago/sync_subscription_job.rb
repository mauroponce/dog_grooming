module PlatformMercadoPago
  class SyncSubscriptionJob < ApplicationJob
    queue_as :default

    def perform(provider_subscription_id)
      subscription = Subscription.find_by(provider: "mercado_pago", provider_subscription_id: provider_subscription_id)
      SyncSubscription.call(subscription) if subscription
    end
  end
end
