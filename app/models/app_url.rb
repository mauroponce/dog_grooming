class AppUrl
  LOCAL_HOST = "localhost:3003"
  PRODUCTION_HOST = "dog-grooming.example.com"

  def self.host
    ENV.fetch("APP_HOST", Rails.env.production? ? PRODUCTION_HOST : LOCAL_HOST)
  end

  def self.protocol
    ENV.fetch("APP_PROTOCOL", Rails.env.production? ? "https" : "http")
  end

  def self.base_url
    "#{protocol}://#{host}"
  end
end
