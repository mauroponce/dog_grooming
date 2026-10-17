class EmployeeInvitationsMailer < ApplicationMailer
  def invite(membership, token)
    @membership = membership
    @business = membership.business
    @inviter_name = inviter_name
    @invitation_url = employee_invitation_url(token: token, host: app_host, protocol: app_protocol)

    mail subject: "#{@inviter_name} te invitó a #{@business.name} en Cita.pet", to: membership.email_address
  end

  private
    def inviter_name
      inviter = @membership.invited_by
      return @business.name if inviter.blank?

      @business.employee_memberships.find_by(user: inviter)&.name.presence ||
        inviter.email_address.presence ||
        @business.name
    end
end
