class StaffAccessMailer < ApplicationMailer
  def magic_link(user)
    @user = user
    @url = magic_link_url(user.magic_login_token, host: app_host, protocol: app_protocol)

    mail subject: "Acceso a Cita.pet", to: user.email_address
  end

  def welcome(user, business)
    @user = user
    @business = business
    @url = new_session_url(host: app_host, protocol: app_protocol)

    mail subject: "Tu cuenta de Cita.pet está lista", to: user.email_address
  end
end
