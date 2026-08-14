class BusinessMailer < ApplicationMailer
  def new_deposit_proof(appointment)
    @appointment = appointment
    @business = appointment.business
    @url = admin_appointment_url(appointment, host: app_host, protocol: app_protocol)

    mail subject: "Nuevo comprobante de seña para revisar", to: @business.owner.email_address
  end

  def new_waitlist_entry(entry)
    @entry = entry
    @business = entry.center
    @url = admin_root_url(host: app_host, protocol: app_protocol)

    mail subject: "Nueva clienta en lista de espera", to: @business.owner.email_address
  end

  def booking_cancelled(appointment)
    @appointment = appointment
    @business = appointment.business
    @url = admin_appointment_url(appointment, host: app_host, protocol: app_protocol)

    mail subject: "Un cliente canceló un turno", to: @business.owner.email_address
  end

  def booking_confirmed_by_mercado_pago(appointment)
    @appointment = appointment
    @business = appointment.business
    @url = admin_appointment_url(appointment, host: app_host, protocol: app_protocol)
    @google_calendar_url = appointment.google_calendar_url

    mail subject: "Turno confirmado con pago de Mercado Pago", to: @business.owner.email_address
  end

  def follow_up_digest(business, reminders = nil)
    @business = business
    @reminders = Array(reminders.presence || business.customer_reminders.pending.where(reminder_type: "service_follow_up").includes(:customer_profile, :service).order(:remind_at).limit(10))
    @url = admin_root_url(host: app_host, protocol: app_protocol)

    mail subject: "Clientas para contactar esta semana", to: @business.owner.email_address
  end

  def daily_digest(business)
    @business = business
    @today = Time.zone.today
    @appointments = business.appointments.includes(:service).where(starts_at: @today.beginning_of_day..@today.end_of_day).order(:starts_at)
    @pending_proofs = business.appointments.awaiting_deposit_review.includes(:service).order(:starts_at).limit(5)
    @follow_ups = business.customer_reminders.pending.where(reminder_type: "service_follow_up").includes(:customer_profile, :service).order(:remind_at).limit(5)
    @waitlist_entries = business.waitlist_entries.visible.includes(:service).order(:created_at).limit(5)
    @gaps = Availability::FillableGaps.new(business: business, date: @today).call.first(5)
    @url = admin_root_url(host: app_host, protocol: app_protocol)

    mail subject: "Resumen de hoy en Dog Grooming", to: @business.owner.email_address
  end

  def weekly_digest(business)
    @business = business
    range = Time.zone.today.beginning_of_week.beginning_of_day..Time.zone.today.end_of_week.end_of_day
    @appointments = business.appointments.includes(:service).where(starts_at: range)
    @completed_count = @appointments.count(&:completed?)
    @cancelled_count = @appointments.count(&:canceled?)
    @no_show_count = @appointments.count(&:no_show?)
    @deposit_cents = @appointments.sum(&:deposit_amount_cents)
    @top_services = @appointments.group_by(&:service).transform_values(&:size).sort_by { |_service, count| -count }.first(5)
    @url = admin_root_url(host: app_host, protocol: app_protocol)

    mail subject: "Resumen semanal de Dog Grooming", to: @business.owner.email_address
  end

end
