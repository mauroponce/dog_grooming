class CustomerPortalMailer < ApplicationMailer
  def magic_link(token_record, raw_token)
    @token_record = token_record
    @business = token_record.business
    @access_url = PublicUrls.url(:customer_portal_access, @business, raw_token, host: app_host, protocol: app_protocol)
    @expires_at = token_record.expires_at

    mail subject: "Tu acceso a tus turnos en #{@business.name}", to: token_record.email
  end

end
