module PlatformMercadoPago
  class SyncAuthorizedPaymentJob < ApplicationJob
    queue_as :default

    def perform(provider_invoice_id)
      payload = Client.new.fetch_authorized_payment!(provider_invoice_id)
      ApplyAuthorizedPayment.call(payload)
    end
  end
end
