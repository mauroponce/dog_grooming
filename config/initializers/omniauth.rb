google_client_id = ENV.fetch("GOOGLE_CLIENT_ID", nil)
google_client_secret = ENV.fetch("GOOGLE_CLIENT_SECRET", nil)

if Rails.env.production? && (google_client_id.blank? || google_client_secret.blank?)
  raise "GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be configured in production."
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    google_client_id.presence || "test-google-client-id",
    google_client_secret.presence || "test-google-client-secret",
    scope: "email,profile",
    prompt: "select_account"
end
