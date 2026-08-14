require "resend_delivery_method"

ActionMailer::Base.add_delivery_method(
  :resend,
  ResendDeliveryMethod,
  api_key: ENV["RESEND_API_KEY"],
  from: ResendDeliveryMethod.configured_from,
  endpoint: ENV.fetch("RESEND_ENDPOINT", ResendDeliveryMethod::DEFAULT_ENDPOINT)
)
