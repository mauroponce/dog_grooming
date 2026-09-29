module SelfRegistration
  class CreateAccount
    def self.call(params)
      values = params.to_h.symbolize_keys
      password = values[:password].to_s
      raise ArgumentError, "La contraseña debe tener al menos 8 caracteres." if password.length < 8
      raise ArgumentError, "Las contraseñas no coinciden." unless password == values[:password_confirmation].to_s

      User.transaction do
        result = SuperAdmin::CreateBusinessAccount.call(
          business_name: values[:business_name],
          owner_name: values[:owner_name],
          owner_email: values[:owner_email],
          contact_phone: values[:contact_phone],
          password: password,
          billing_enabled: true
        )
        result.business.subscription.update!(provider: "mercado_pago")
        result
      end
    end
  end
end
