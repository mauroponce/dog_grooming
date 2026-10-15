module GoogleOAuth
  class Identity
    class Invalid < StandardError; end

    attr_reader :uid, :email_address, :name

    def self.from_omniauth(auth)
      new(
        provider: auth["provider"],
        uid: auth["uid"],
        email_address: auth.dig("info", "email"),
        name: auth.dig("info", "name"),
        email_verified: auth.dig("extra", "raw_info", "email_verified")
      )
    end

    def self.from_session(attributes)
      new(**attributes.symbolize_keys, provider: "google_oauth2", email_verified: true)
    rescue NoMethodError
      raise Invalid, "La identidad de Google no es válida."
    end

    def initialize(provider:, uid:, email_address:, name:, email_verified:)
      raise Invalid, "El proveedor de acceso no es válido." unless provider == "google_oauth2"
      raise Invalid, "Google no confirmó la dirección de email." unless ActiveModel::Type::Boolean.new.cast(email_verified)

      @uid = uid.to_s
      @email_address = email_address.to_s.strip.downcase
      @name = name.to_s.squish

      raise Invalid, "Google no devolvió una identidad válida." if @uid.blank? || @email_address.blank?
    end

    def session_attributes
      { "uid" => uid, "email_address" => email_address, "name" => name }
    end
  end
end
