class CustomerReminderMailer < ApplicationMailer
  def due(reminder)
    @reminder = reminder
    @customer = reminder.customer_profile
    @business = reminder.business
    @customer_url = admin_customer_profiles_url(customer_id: @customer.id, host: app_host, protocol: app_protocol)

    mail subject: "Recordatorio de cliente", to: reminder.assigned_to.email_address
  end

end
