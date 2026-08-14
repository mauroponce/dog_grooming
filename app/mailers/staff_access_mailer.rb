class StaffAccessMailer < ApplicationMailer
  def magic_link(user)
    @user = user
    @url = magic_link_url(user.magic_login_token, host: app_host, protocol: app_protocol)

    mail subject: "Acceso a Dog Grooming", to: user.email_address
  end

  def welcome(user, business)
    @user = user
    @business = business
    @url = new_session_url(host: app_host, protocol: app_protocol)

    mail subject: "Tu cuenta de Dog Grooming está lista", to: user.email_address
  end
end
