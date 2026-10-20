class BillingMailer < ApplicationMailer
  def reminder(invoice, reminder_type)
    @invoice = invoice
    @business = invoice.business
    @subscription = invoice.subscription
    @reminder_type = reminder_type
    @billing_url = admin_billing_url(host: app_host, protocol: app_protocol)

    mail subject: reminder_subject(reminder_type), to: @business.owner.email_address
  end

  def payment_proof_received(proof)
    @proof = proof
    @invoice = proof.subscription_invoice
    @business = proof.business
    @billing_url = admin_billing_url(host: app_host, protocol: app_protocol)

    mail subject: "Recibimos tu comprobante de pago", to: @business.owner.email_address
  end

  def payment_proof_review_requested(proof, reviewer)
    @proof = proof
    @invoice = proof.subscription_invoice
    @business = proof.business
    @review_url = super_admin_billing_url(host: app_host, protocol: app_protocol, anchor: "payment-#{@invoice.id}")

    mail subject: "Comprobante para revisar: #{@business.name}", to: reviewer.email_address
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

    mail subject: "Tu cuenta de Cita.pet fue pausada temporalmente", to: @business.owner.email_address
  end

  def daily_summary(summary, recipient)
    @summary = summary
    @super_admin_url = super_admin_businesses_url(host: app_host, protocol: app_protocol)

    mail subject: "Resumen de cobros Cita.pet", to: recipient
  end

  private
    def reminder_subject(type)
      {
        "due_4_days" => "Tu suscripción Cita.pet vence en 4 días",
        "due_3_days" => "Tu suscripción Cita.pet vence en 3 días",
        "due_2_days" => "Tu suscripción Cita.pet vence en 2 días",
        "due_1_day" => "Tu suscripción Cita.pet vence mañana",
        "due_today" => "Tu suscripción Cita.pet vence hoy",
        "overdue_2_days" => "Tu pago de Cita.pet está pendiente",
        "overdue_3_days" => "Último día para regularizar tu pago de Cita.pet",
        "suspended_notice" => "Tu cuenta de Cita.pet fue pausada temporalmente"
      }.fetch(type, "Tu pago de Cita.pet está pendiente")
    end
end
