class BillingMailer < ApplicationMailer
  def reminder(invoice, reminder_type)
    @invoice = invoice
    @business = invoice.business
    @subscription = invoice.subscription
    @reminder_type = reminder_type
    @billing_url = admin_billing_url(host: app_host, protocol: app_protocol)
    @transfer_alias = Billing::TransferDetails.alias
    @transfer_account = Billing::TransferDetails.account
    @transfer_holder = Billing::TransferDetails.holder
    @transfer_details_configured = Billing::TransferDetails.configured?

    mail subject: reminder_subject(reminder_type), to: @business.owner.email_address
  end

  def payment_proof_received(proof)
    @proof = proof
    @invoice = proof.subscription_invoice
    @business = proof.business
    @billing_url = admin_billing_url(host: app_host, protocol: app_protocol)

    mail subject: "Recibimos tu comprobante de pago", to: @business.owner.email_address
  end

  def payment_approved(invoice)
    @invoice = invoice
    @business = invoice.business
    @billing_url = admin_billing_url(host: app_host, protocol: app_protocol)

    mail subject: "Tu pago fue aprobado", to: @business.owner.email_address
  end

  def payment_rejected(invoice)
    @invoice = invoice
    @proof = invoice.current_proof
    @business = invoice.business
    @billing_url = admin_billing_url(host: app_host, protocol: app_protocol)

    mail subject: "No pudimos validar tu comprobante", to: @business.owner.email_address
  end

  def account_suspended(invoice)
    @invoice = invoice
    @business = invoice.business
    @billing_url = admin_billing_url(host: app_host, protocol: app_protocol)

    mail subject: "Tu cuenta de Dog Grooming fue pausada temporalmente", to: @business.owner.email_address
  end

  def daily_summary(summary, recipient)
    @summary = summary
    @super_admin_url = super_admin_businesses_url(host: app_host, protocol: app_protocol)

    mail subject: "Resumen de cobros Dog Grooming", to: recipient
  end

  private
    def reminder_subject(type)
      {
        "due_7_days" => "Tu suscripción Dog Grooming vence en 7 días",
        "due_3_days" => "Tu suscripción Dog Grooming vence en 3 días",
        "due_today" => "Tu suscripción Dog Grooming vence hoy",
        "overdue_2_days" => "Tu pago de Dog Grooming está pendiente",
        "overdue_5_days" => "Tu pago de Dog Grooming sigue pendiente",
        "overdue_10_days" => "Vamos a pausar las reservas online de tu cuenta",
        "restricted_notice" => "Tus reservas online fueron pausadas temporalmente",
        "suspended_notice" => "Tu cuenta de Dog Grooming fue pausada temporalmente"
      }.fetch(type, "Tu pago de Dog Grooming está pendiente")
    end
end
