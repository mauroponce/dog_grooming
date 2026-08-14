class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Restablecer tu contraseña", to: user.email_address
  end
end
