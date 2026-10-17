class PublicBookingController < ApplicationController
  WAITLIST_DATE_RANGE_DAYS = 60

  allow_unauthenticated_access

  before_action :set_business
  before_action :track_campaign_visit, only: %i[show new]

  def show
    @services = @business.services.publicly_bookable.includes(:service_category, :service_tags, :employee_memberships, cover_image_attachment: :blob, service_images_attachments: :blob).order(:category, :sort_order, :name)
    @categories = @services.map(&:category_label).uniq
    @service_detail = service_from_public_key(params[:service_detail], scope: @services) if params[:service_detail].present?
    @confirmation = find_confirmation
    sync_mercado_pago_return!(@confirmation) if @confirmation.present?
    @landing = ::Public::BusinessLandingPresenter.new(business: @business, params: params, host: request.host)
  end

  def new
    redirect_to public_business_path(@business.slug), alert: "La agenda no está disponible en este momento." and return unless @business.booking_available?

    @services = @business.services.publicly_bookable.includes(:service_category, :service_tags, :employee_memberships, :service_availability_rules, service_variants: :pet_size_band, service_resources: :bookable_resource, service_images_attachments: :blob).order(:category, :sort_order, :name).to_a
    @categories = @services.map(&:category_label).uniq
    @selected_services = selected_services_from_params
    @public_extras = @business.extras.publicly_visible.order(:title).to_a
    @selected_extras = @public_extras.select { |extra| Array(params[:extra_ids]).map(&:to_s).include?(extra.id.to_s) }
    redirect_to public_business_path(@business.slug), alert: "El servicio no está disponible." and return if selected_service_keys.any? && @selected_services.blank?
    @service = @selected_services.first
    @service_variant = selected_variant_from_params(@service, params[:service_variant_id])
    ensure_requested_category_matches_service!
    @service_detail = service_from_public_key(params[:service_detail], scope: @services) if params[:service_detail].present?
    @date = Date.parse(params[:date].presence || Time.zone.today.to_s)
    @date = Time.zone.today if @date < Time.zone.today
    @date = booking_horizon_end if @date > booking_horizon_end
    @date = next_enabled_booking_date(from: @date) || @date if @selected_services.any?
    @month_date = Date.parse(params[:month].presence || @date.beginning_of_month.to_s).beginning_of_month
    @date_window_start = date_window_start_for(@date)
    @selected_starts_at = Time.zone.parse(params[:starts_at]) if params[:starts_at].present?
    @show_professional_modal = params[:professional_modal].present?
    @professional_mode = professional_mode
    @employees_by_service = employees_by_service
    @employee_memberships = available_employees_for_services
    @selected_employee_membership = selected_global_employee
    @selected_professionals_by_service = selected_professionals_by_service
    @single_employee_membership = single_employee_for_all_services
    @professional_step_required = professional_step_required?
    @booking_step = booking_step
    @booking_draft_token = params[:draft].presence
    @booking_draft = find_booking_draft(@booking_draft_token) if @booking_draft_token.present?
    @booking_draft_token = nil if @booking_draft_token.present? && @booking_draft.blank?
    if @booking_step == "reserve" && @booking_draft.blank?
      redirect_to missing_booking_draft_redirect_path, alert: "Completá tus datos personales antes de reservar." and return
    end
    @total_duration_minutes = @selected_services.sum { |service| booking_service(service).duration_minutes }
    @total_price_cents = @selected_services.sum { |service| booking_service(service).price_cents } + @selected_extras.sum(&:price_cents)
    prepare_sequence_calendar if %w[schedule details reserve waitlist].include?(@booking_step)
    prepare_waitlist_context if @booking_step == "waitlist"
    prepare_reserve_context if @booking_step == "reserve"
  rescue ActiveRecord::RecordNotFound, Date::Error, ArgumentError
    redirect_to public_business_path(@business.slug), alert: "Selección inválida."
  end

  def create
    @booking_submission_params = booking_params
    @booking_draft_token = @booking_submission_params[:draft_token].presence
    @booking_draft = find_booking_draft(@booking_draft_token) if @booking_draft_token.present?
    @booking_submission_params = booking_submission_params_with_draft(@booking_submission_params, @booking_draft)
    @selected_services = selected_services_from_booking_params
    @selected_extras = @business.extras.publicly_visible.where(id: Array(@booking_submission_params[:extra_ids])).to_a
    raise ActiveRecord::RecordNotFound if @selected_services.blank?
    @service = @selected_services.first
    starts_at = parse_starts_at!(@booking_submission_params[:starts_at])
    validate_customer_details!

    case @booking_submission_params[:submission_step].presence
    when "details"
      handle_details_submission(starts_at)
    when "confirm"
      appointments = create_appointments_from_submission!(starts_at: starts_at, payment_method: nil)
      clear_booking_draft(@booking_draft_token)
      session.delete(:booking_intent_id)
      redirect_to public_business_path(@business.slug, confirmation: confirmation_token(appointments.first))
    when "mercado_pago"
      appointments = create_appointments_from_submission!(starts_at: starts_at, payment_method: "mercado_pago")
      session.delete(:booking_intent_id)
      mercado_pago_payment = create_mercado_pago_payment_for!(appointments)
      clear_booking_draft(@booking_draft_token)
      redirect_to mercado_pago_payment.checkout_url, allow_other_host: true, notice: "Te llevamos a Mercado Pago para completar el pago."
    when "start_manual_transfer"
      appointment = active_manual_payment_appointment_from_draft
      if appointment.blank?
        appointments = create_appointments_from_submission!(starts_at: starts_at, payment_method: "manual_transfer")
        remember_draft_appointments(appointments)
        appointment = appointments.first
      end
      redirect_to reserve_booking_path_for_draft(manual_transfer: 1), notice: "El turno queda bloqueado por #{appointment.service.deposit_payment_deadline_minutes} minutos mientras subís el comprobante."
    when "upload_manual_transfer"
      appointment = appointment_from_upload_token!(@booking_submission_params[:appointment_token])
      expire_pending_deposit_if_deadline_passed!(appointment)
      redirect_to public_business_path(@business.slug), alert: "Venció el plazo para subir el comprobante. El horario volvió a estar disponible." and return if appointment.expired?

      DepositProofs::ReplaceService.new(booking: appointment, file: @booking_submission_params[:deposit_receipt]).call
      clear_booking_draft(@booking_draft_token)
      session.delete(:booking_intent_id)
      redirect_to public_business_path(@business.slug, confirmation: confirmation_token(appointment)), notice: "Recibimos tu comprobante. El turno queda pendiente de revisión."
    else
      handle_legacy_booking_submission(starts_at)
    end
  rescue Appointments::BlockedCustomer, Appointments::UnavailableSlot, ActiveRecord::RecordInvalid, ArgumentError, TypeError, MercadoPago::Client::Error => error
    redirect_to fallback_booking_path, alert: error.message
  end

  def calendar
    appointment = find_confirmation!
    send_data calendar_payload(appointment),
      filename: "turno-#{appointment.business.slug}-#{appointment.starts_at.strftime('%Y%m%d%H%M')}.ics",
      type: "text/calendar; charset=utf-8"
  end

  helper_method :employee_for_service

  private
    def set_business
      @business = Business.find_by_custom_domain(request.host) || Business.find_by(slug: params[:slug])
      redirect_to root_path, alert: "La página que buscás no existe." if @business.blank?
      redirect_to root_path, alert: "La página que buscás no está disponible." if @business.present? && !@business.access_active? && !@business.billing_suspended?
    end

    def track_campaign_visit
      return if @business.blank?
      return if params[:src].blank? && params[:clid].blank?

      Sales::TrackVisit.new(controller: self, business: @business).call
    end

    def booking_params
      params.require(:booking).permit(
        :starts_at,
        :branch_id,
        :employee_membership_id,
        :professional_mode,
        :booking_intent_id,
        :submission_step,
        :draft_token,
        :appointment_token,
        :customer_name,
        :customer_phone,
        :customer_email,
        :pet_id,
        :pet_name,
        :pet_breed,
        :pet_sex,
        :pet_birth_date,
        :pet_coat_type,
        :pet_coat_details,
        :service_variant_id,
        :deposit_receipt,
        :payment_method,
        service_ids: [],
        extra_ids: [],
        professionals: {}
      )
    end

    def booking_submission_params
      @booking_submission_params || booking_params
    end

    def parse_starts_at!(value)
      raise ArgumentError, "Selecciona un horario disponible" if value.blank?

      Time.zone.parse(value)
    end

    def create_mercado_pago_payment_for!(appointments)
      mercado_pago_appointments = appointments.select(&:mercado_pago_payment_pending?)
      raise ArgumentError, "No hay pagos de Mercado Pago para iniciar." if mercado_pago_appointments.blank?

      MercadoPago::CreateBookingPreference.call(
        appointments: mercado_pago_appointments,
        host: public_callback_host,
        protocol: public_callback_protocol
      ).tap do
      end
    rescue StandardError => error
      appointments.each do |appointment|
        next if appointment.canceled?

        appointment.update!(
          status: :canceled,
          canceled_at: Time.current,
          canceled_by: "system",
          cancellation_reason: "No se pudo iniciar el pago con Mercado Pago: #{error.message}",
          canceled_late: false
        )
      end
      raise
    end

    def sync_mercado_pago_return!(appointment)
      return unless appointment.pending_payment?
      return unless params[:mp_status].to_s == "success"

      payment_id = params[:payment_id].presence || params[:collection_id].presence
      return if payment_id.blank? || payment_id.to_s == "null"

      payment = appointment.appointment_payment
      return if payment.blank? || payment.approved?

      remote_payment = MercadoPago::Client.for_connection(appointment.business.mercado_pago_connection).fetch_payment!(payment_id)
      return unless remote_payment["status"].to_s == "approved"
      return unless remote_payment["external_reference"].to_s == payment.external_reference

      MercadoPago::ApproveBookingPayment.call(payment: payment, payload: remote_payment)
      appointment.reload
    rescue StandardError => error
      Rails.logger.warn("Could not sync Mercado Pago return for appointment #{appointment.id}: #{error.class}")
    end

    def prepare_calendar
      @calendar_days = (@month_date..@month_date.end_of_month).to_a
      @calendar_leading_blanks = @month_date.wday
      @available_dates = @calendar_days.index_with do |date|
        Availability::Slots.public_for(business: @business, service: @service, date: date, employee_membership: @employee_membership).any?
      end
      @previous_month = @month_date.prev_month if @month_date > Time.zone.today.beginning_of_month
      @next_month = @month_date.next_month if @month_date.next_month <= 60.days.from_now.to_date.beginning_of_month
    end

    def prepare_sequence_calendar
      @calendar_days = (@month_date..@month_date.end_of_month).to_a
      @calendar_leading_blanks = @month_date.wday
      horizon_end = booking_horizon_end
      @date_window_days = (@date_window_start..[ @date_window_start + 7, horizon_end ].min).to_a
      @previous_date_window_start = [ @date_window_start - 8, Time.zone.today ].max if @date_window_start > Time.zone.today
      @next_date_window_start = @date_window_start + 8 if @date_window_start + 8 <= horizon_end
      @sequence_slots_by_date = {}
      @slots = slots_for_calendar_date(@date)
      @date_window_availability = @date_window_days.index_with { |date| booking_date_enabled?(date) }
      @next_available_date = next_available_sequence_date(from: @date, horizon_end: horizon_end) if @slots.blank?
      @available_dates = @calendar_days.index_with do |date|
        booking_date_enabled?(date)
      end
      @previous_month = @month_date.prev_month if @month_date > Time.zone.today.beginning_of_month
      @next_month = @month_date.next_month if @month_date.next_month <= 60.days.from_now.to_date.beginning_of_month
      @slot_prices = @slots.index_with { @total_price_cents }
      @slot_discounts = @slots.index_with { 0.to_d }
    end

    def prepare_reserve_context
      @manual_payment_appointment = active_manual_payment_appointment_from_draft
      return if @manual_payment_appointment.blank?

      expire_pending_deposit_if_deadline_passed!(@manual_payment_appointment)
      if @manual_payment_appointment.expired?
        clear_booking_draft(@booking_draft_token)
        redirect_to public_business_path(@business.slug), alert: "Venció el plazo para subir el comprobante. El horario volvió a estar disponible."
        return
      end

      @manual_payment_deadline = @manual_payment_appointment.created_at + @manual_payment_appointment.service.deposit_payment_deadline_minutes.minutes
      @manual_payment_upload_token = @manual_payment_appointment.deposit_upload_token
    end

    def prepare_team_context
      @branches = @business.team_features_available? ? @business.branches.active.order(:name).to_a : []
      @branch = @branches.find { |branch| branch.id == params[:branch_id].to_i } || @branches.first
      @employee_memberships = []
      @employee_membership = nil

      return unless @business.team_features_available?

      employees = @business.employee_memberships.available_for_booking.includes(:branch, :user).order(:name).to_a
      employees = employees.select { |membership| @service.employee_membership_ids.include?(membership.id) } if @service.employee_membership_ids.any?
      employees = employees.select { |membership| membership.branch_id.blank? || membership.branch_id == @branch&.id } if @branch.present?
      @employee_memberships = employees
      @professional_selector_visible = employees.many? && !@service.hide_professional_selection?
      @employee_membership = selected_public_employee(employees)
      @branch = @employee_membership.branch if @employee_membership&.branch.present?
    end

    def public_callback_host
      forwarded_host = request.headers.fetch("X-Forwarded-Host", nil).to_s.split(",").first&.strip
      forwarded_host.presence || request.host_with_port.presence || AppUrl.host
    end

    def public_callback_protocol
      forwarded_protocol = request.headers.fetch("X-Forwarded-Proto", nil).to_s.split(",").first&.strip
      protocol = forwarded_protocol.presence || request.protocol.presence || AppUrl.protocol

      protocol.to_s.delete_suffix("://")
    end

    def selected_employee_for_booking
      return unless @business.public_booking_allow_professional_selection?
      return if @service&.hide_professional_selection?
      return unless @business.team_features_available? && booking_submission_params[:employee_membership_id].present?

      @business.employee_memberships.available_for_booking.find_by(id: booking_submission_params[:employee_membership_id])
    end

    def booking_step
      requested = params[:step].presence_in(%w[services extras professionals schedule waitlist details reserve])
      return "services" if @service&.tiered_pricing? && @service_variant.blank?
      return "extras" if requested == "extras" && @selected_services.any? && @public_extras.any?
      return (@selected_services.any? ? "schedule" : "services") if requested == "professionals" && !professional_step_required?
      return requested if requested.present?
      return "services" if @selected_services.blank?
      return (professional_step_required? ? "professionals" : (@public_extras.any? ? "extras" : "schedule")) if direct_service_booking?

      "services"
    end

    def selected_service_keys
      keys = Array(params[:service_ids]).compact_blank
      keys << params[:service_id] if params[:service_id].present?
      keys << params[:service_slug] if params[:service_slug].present?
      keys.map { |key| key.to_s.strip }.uniq
    end

    def direct_service_booking?
      params[:service_slug].present? || (params[:service_id].present? && params[:service_ids].blank?)
    end

    def selected_services_from_params
      services_from_public_keys(selected_service_keys)
    end

    def ensure_requested_category_matches_service!
      return if params[:category_slug].blank? || @service.blank?
      return if @service.service_category&.slug == params[:category_slug]

      raise ActiveRecord::RecordNotFound
    end

    def selected_services_from_booking_params
      services_from_public_keys(Array(booking_submission_params[:service_ids]).compact_blank.first(1))
    end

    def selected_variant_from_params(service, variant_id)
      return if service.blank? || !service.tiered_pricing?

      variant = service.service_variants.active.find_by(id: variant_id)
      raise ArgumentError, "Elegí el tamaño de la mascota para este servicio." if variant.blank? && variant_id.present?
      variant
    end

    def booking_service(service, variant: nil)
      variant ||= @service_variant if service == @service
      Bookings::ServiceSelection.new(service: service, variant: variant)
    end

    def professional_mode
      return "any" unless @business.public_booking_allow_professional_selection?

      params[:professional_mode].presence_in(%w[any single]) || "any"
    end

    def date_window_start_for(date)
      horizon_start = Time.zone.today
      horizon_end = 60.days.from_now.to_date
      window_start = params[:date_window_start].present? ? Date.parse(params[:date_window_start]) : date

      return horizon_start if window_start < horizon_start
      return horizon_end if window_start > horizon_end

      window_start
    end

    def available_employees_for_services
      return [] unless @business.team_features_available?

      @available_employees_for_services ||= @business.employee_memberships.available_for_booking.includes(:branch, :user, :employee_availability_rules).order(:sort_order, :name).to_a
    end

    def employees_by_service
      available = available_employees_for_services
      @selected_services.index_with do |service|
        employees = available
        employees = employees.select { |membership| service.employee_membership_ids.include?(membership.id) } if service.employee_membership_ids.any?
        employees
      end
    end

    def handle_details_submission(starts_at)
      raise Appointments::UnavailableSlot, "Seleccioná un horario disponible para todos los servicios." unless sequence_available_for_booking?(starts_at, @selected_services)

      token = store_booking_draft(starts_at:)
      redirect_to reserve_booking_path(token)
    end

    def handle_legacy_booking_submission(starts_at)
      payment_method = booking_submission_params[:payment_method].presence
      appointments = create_appointments_from_submission!(
        starts_at: starts_at,
        payment_method: payment_method,
        deposit_receipt: booking_submission_params[:deposit_receipt]
      )
      session.delete(:booking_intent_id)
      appointment = appointments.first

      mercado_pago_appointments = appointments.select(&:mercado_pago_payment_pending?)
      if mercado_pago_appointments.any?
        mercado_pago_payment = create_mercado_pago_payment_for!(appointments)
        redirect_to mercado_pago_payment.checkout_url, allow_other_host: true, notice: "Te llevamos a Mercado Pago para completar el pago."
        return
      end

      notice = appointments.any?(&:deposit_submitted?) ? "Recibimos tu comprobante. El turno queda pendiente de revisión." : "Tu solicitud de turno fue enviada."
      redirect_to public_business_path(@business.slug, confirmation: confirmation_token(appointment)), notice: notice
    end

    def create_appointments_from_submission!(starts_at:, payment_method:, deposit_receipt: nil)
      raise Appointments::UnavailableSlot, "Seleccioná un horario disponible para todos los servicios." unless sequence_available_for_booking?(starts_at, @selected_services)

      appointments = []
      @business.transaction do
        current_starts_at = starts_at
        manual_receipt_attached = false

        @selected_services.each do |service|
          variant = selected_variant_from_params(service, booking_submission_params[:service_variant_id])
          preferred_employee = employee_for_service_booking(service)
          receipt = (!manual_receipt_attached && payment_method == "manual_transfer" && service.deposit_required?) ? deposit_receipt : nil
          appointment = Appointments::CreateBooking.call(
            business: @business,
            service: service,
            starts_at: current_starts_at,
            customer_name: booking_submission_params[:customer_name],
            customer_phone: booking_submission_params[:customer_phone],
            customer_email: booking_submission_params[:customer_email].presence,
            pet_id: booking_submission_params[:pet_id].presence,
            pet_name: booking_submission_params[:pet_name],
            pet_breed: booking_submission_params[:pet_breed],
            pet_sex: booking_submission_params[:pet_sex],
            pet_birth_date: booking_submission_params[:pet_birth_date],
            pet_coat_type: booking_submission_params[:pet_coat_type],
            pet_coat_details: booking_submission_params[:pet_coat_details],
            service_variant: variant,
            branch: preferred_employee&.branch || selected_branch_for_booking,
            employee_membership: preferred_employee,
            deposit_receipt: receipt,
            payment_method: payment_method,
            extra_ids: @selected_extras.map(&:id)
          )
          manual_receipt_attached ||= payment_method == "manual_transfer" && service.deposit_required? && deposit_receipt.present?
          Sales::RecordAttribution.new(appointment: appointment, attribution: session[:sales_attribution]).call
          appointments << appointment
          current_starts_at += booking_service(service, variant: variant).duration_minutes.minutes
        end
      end

      appointments
    end

    def validate_customer_details!
      raise ArgumentError, "Completá tu nombre y apellido." if booking_submission_params[:customer_name].blank?
      raise ArgumentError, "Completá tu teléfono." if booking_submission_params[:customer_phone].blank?
      if booking_submission_params[:customer_email].present? && !booking_submission_params[:customer_email].to_s.match?(URI::MailTo::EMAIL_REGEXP)
        raise ArgumentError, "Ingresá un email válido."
      end
      raise ArgumentError, "Completá el nombre de tu mascota." if booking_submission_params[:pet_name].blank?
    end

    def booking_submission_params_with_draft(params, draft)
      attrs = params.to_h.with_indifferent_access
      return attrs if draft.blank?

      draft_attrs = draft.with_indifferent_access
      attrs[:service_ids] = draft_attrs[:service_ids] if attrs[:service_ids].blank?
      attrs[:extra_ids] = draft_attrs[:extra_ids] if attrs[:extra_ids].blank?
      attrs[:starts_at] = draft_attrs[:starts_at] if attrs[:starts_at].blank?
      attrs[:professional_mode] = draft_attrs[:professional_mode] if attrs[:professional_mode].blank?
      attrs[:employee_membership_id] = draft_attrs[:employee_membership_id] if attrs[:employee_membership_id].blank?
      attrs[:professionals] = draft_attrs[:professionals] if attrs[:professionals].blank?
      attrs[:customer_name] = draft_attrs[:customer_name] if attrs[:customer_name].blank?
      attrs[:customer_phone] = draft_attrs[:customer_phone] if attrs[:customer_phone].blank?
      attrs[:customer_email] = draft_attrs[:customer_email] if attrs[:customer_email].blank?
      attrs[:pet_id] = draft_attrs[:pet_id] if attrs[:pet_id].blank?
      attrs[:pet_name] = draft_attrs[:pet_name] if attrs[:pet_name].blank?
      attrs[:pet_breed] = draft_attrs[:pet_breed] if attrs[:pet_breed].blank?
      attrs[:pet_sex] = draft_attrs[:pet_sex] if attrs[:pet_sex].blank?
      attrs[:pet_birth_date] = draft_attrs[:pet_birth_date] if attrs[:pet_birth_date].blank?
      attrs[:pet_coat_type] = draft_attrs[:pet_coat_type] if attrs[:pet_coat_type].blank?
      attrs[:pet_coat_details] = draft_attrs[:pet_coat_details] if attrs[:pet_coat_details].blank?
      attrs[:service_variant_id] = draft_attrs[:service_variant_id] if attrs[:service_variant_id].blank?
      attrs
    end

    def professionals_hash_from(value)
      return {} if value.blank?
      return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
      return value.to_h if value.respond_to?(:to_h)

      {}
    end

    def booking_drafts
      session[:public_booking_drafts].is_a?(Hash) ? session[:public_booking_drafts] : {}
    end

    def find_booking_draft(token)
      token = token.to_s
      return if token.blank?

      draft = booking_drafts[token]
      return if draft.blank? || draft["business_id"].to_i != @business.id

      draft
    end

    def store_booking_draft(starts_at:)
      token = @booking_draft_token.presence || SecureRandom.urlsafe_base64(18)
      # The public flow uses a cookie-backed session. Keeping previous drafts
      # indefinitely can exceed the browser's 4 KB cookie limit, causing the
      # redirect to fail and losing the active reservation flow. A browser can
      # only progress one active booking at a time, so retain just this draft.
      drafts = {}
      drafts[token] = {
        "business_id" => @business.id,
        "service_ids" => Array(booking_submission_params[:service_ids]).compact_blank.first(1),
        "service_variant_id" => booking_submission_params[:service_variant_id].to_s,
        "extra_ids" => Array(booking_submission_params[:extra_ids]).compact_blank,
        "starts_at" => starts_at.iso8601,
        "professional_mode" => booking_submission_params[:professional_mode].presence || "any",
        "employee_membership_id" => booking_submission_params[:employee_membership_id].presence,
        "professionals" => professionals_hash_from(booking_submission_params[:professionals]),
        "customer_name" => booking_submission_params[:customer_name].to_s,
        "customer_phone" => booking_submission_params[:customer_phone].to_s,
        "customer_email" => booking_submission_params[:customer_email].to_s,
        "pet_id" => booking_submission_params[:pet_id].to_s,
        "pet_name" => booking_submission_params[:pet_name].to_s,
        "pet_breed" => booking_submission_params[:pet_breed].to_s,
        "pet_sex" => booking_submission_params[:pet_sex].to_s,
        "pet_birth_date" => booking_submission_params[:pet_birth_date].to_s,
        "pet_coat_type" => booking_submission_params[:pet_coat_type].to_s,
        "pet_coat_details" => booking_submission_params[:pet_coat_details].to_s,
        "appointment_ids" => Array(@booking_draft&.dig("appointment_ids")),
        "created_at" => Time.current.iso8601
      }.compact
      session[:public_booking_drafts] = drafts
      token
    end

    def clear_booking_draft(token)
      return if token.blank?

      drafts = booking_drafts
      drafts.delete(token.to_s)
      session[:public_booking_drafts] = drafts
    end

    def remember_draft_appointments(appointments)
      return if @booking_draft_token.blank?

      drafts = booking_drafts
      draft = drafts[@booking_draft_token].to_h
      draft["appointment_ids"] = appointments.map(&:id)
      drafts[@booking_draft_token] = draft
      session[:public_booking_drafts] = drafts
      @booking_draft = draft
    end

    def draft_appointments
      ids = Array(@booking_draft&.dig("appointment_ids")).map(&:to_i).select(&:positive?)
      return Appointment.none if ids.blank?

      @business.appointments.where(id: ids)
    end

    def active_manual_payment_appointment_from_draft
      draft_appointments.detect { |appointment| appointment.manual_payment_required? && !appointment.terminal_status? }
    end

    def expire_pending_deposit_if_deadline_passed!(appointment)
      return unless appointment.pending_deposit?

      deadline = appointment.created_at + appointment.service.deposit_payment_deadline_minutes.minutes
      return if Time.current < deadline

      appointment.update!(
        status: :expired,
        cancellation_reason: "Venció el plazo para subir el comprobante de seña"
      )
      appointment.business.provider_events.create!(
        event_type: "deposit_deadline_expired",
        title: "Seña vencida",
        body: "Venció la seña de #{appointment.customer_name} para #{appointment.service.name}. El horario volvió a quedar disponible.",
        metadata: { appointment_id: appointment.id }
      )
    end

    def appointment_from_upload_token!(token)
      appointment = Appointment.find_signed!(token, purpose: :deposit_upload)
      raise ActiveRecord::RecordNotFound unless appointment.business_id == @business.id

      appointment
    end

    def reserve_booking_path(token = @booking_draft_token, extra_params = {})
      starts_at = Time.zone.parse(booking_submission_params[:starts_at])
      new_public_booking_path(
        @business.slug,
        {
          service_ids: Array(booking_submission_params[:service_ids]).compact_blank.first(1),
          service_variant_id: booking_submission_params[:service_variant_id].presence,
          step: "reserve",
          draft: token,
          starts_at: starts_at.iso8601,
          date: starts_at.to_date,
          professional_mode: booking_submission_params[:professional_mode].presence || "any",
          employee_membership_id: booking_submission_params[:employee_membership_id].presence,
          professionals: professionals_hash_from(booking_submission_params[:professionals])
        }.compact.merge(extra_params)
      )
    end

    def reserve_booking_path_for_draft(extra_params = {})
      reserve_booking_path(@booking_draft_token, extra_params)
    end

    def missing_booking_draft_redirect_path
      if @selected_starts_at.present? && @selected_services.any?
        new_public_booking_path(@business.slug, booking_calendar_params(date: @date, step: "details").merge(starts_at: @selected_starts_at.iso8601))
      elsif @selected_services.any?
        new_public_booking_path(@business.slug, booking_calendar_params(date: @date, step: "schedule"))
      else
        public_business_path(@business.slug)
      end
    end

    def selected_global_employee
      return unless @business.public_booking_allow_professional_selection?
      return unless professional_mode == "single"

      available_employees_for_services.find { |membership| membership.id == params[:employee_membership_id].to_i }
    end

    def selected_professionals_by_service
      return {} unless @business.public_booking_allow_professional_selection?

      raw = params[:professionals].respond_to?(:to_unsafe_h) ? params[:professionals].to_unsafe_h : params[:professionals].to_h
      @selected_services.index_with do |service|
        employee_id = (raw[service.slug].presence || raw[service.id.to_s].presence).to_i
        employees_by_service.fetch(service).find { |membership| membership.id == employee_id }
      end
    rescue NoMethodError
      {}
    end

    def employee_for_service(service)
      return unless @business.public_booking_allow_professional_selection?
      return @selected_employee_membership if professional_mode == "single"

      nil
    end

    def employee_for_service_booking(service)
      return unless @business.public_booking_allow_professional_selection?

      mode = booking_submission_params[:professional_mode].presence_in(%w[any single]) || "any"
      return @business.employee_memberships.available_for_booking.find_by(id: booking_submission_params[:employee_membership_id]) if mode == "single" && booking_submission_params[:employee_membership_id].present?

      nil
    end

    def sequence_slots_for(date)
      first_service = @selected_services.first
      return [] if first_service.blank?

      public_slots = Availability::Slots.public_for(
        business: @business,
        service: booking_service(first_service),
        date: date,
        employee_membership: employee_for_service(first_service)
      )
      return public_slots if @selected_services.one?

      public_slots.select { |starts_at| sequence_available?(starts_at, @selected_services) }
    end

    def slots_for_calendar_date(date)
      @sequence_slots_by_date ||= {}
      @sequence_slots_by_date[date] ||= sequence_slots_for(date)
    end

    def next_available_sequence_date(from:, horizon_end:)
      ((from + 1)..horizon_end).find { |date| booking_date_enabled?(date) && slots_for_calendar_date(date).any? }
    end

    def booking_horizon_end
      WAITLIST_DATE_RANGE_DAYS.days.from_now.to_date
    end

    def booking_date_enabled?(date)
      date = date.to_date
      return false if date < Time.zone.today || date > booking_horizon_end

      @selected_services.any? && @selected_services.all? { |service| service.available_on_date?(date) }
    end

    def next_enabled_booking_date(from:)
      (from..booking_horizon_end).find { |date| booking_date_enabled?(date) }
    end

    def sequence_available?(starts_at, services)
      current_starts_at = starts_at
      services.all? do |service|
        selected_service = booking_service(service)
        available = public_service_available_with_assignment?(selected_service, current_starts_at, employee_for_service(service))
        current_starts_at += selected_service.duration_minutes.minutes
        available
      end
    end

    def sequence_available_for_booking?(starts_at, services)
      current_starts_at = starts_at
      services.all? do |service|
        variant = selected_variant_from_params(service, booking_submission_params[:service_variant_id])
        selected_service = booking_service(service, variant: variant)
        available = public_service_available_with_assignment?(selected_service, current_starts_at, employee_for_service_booking(service))
        current_starts_at += selected_service.duration_minutes.minutes
        available
      end
    end

    def public_service_available_with_assignment?(service, starts_at, preferred_employee)
      return Availability::Slots.public_available?(business: @business, service: service, starts_at: starts_at) unless @business.team_features_available?
      assignable_employees = assignable_employees_for_service(service)
      if assignable_employees.blank?
        return Availability::Slots.public_available?(business: @business, service: service, starts_at: starts_at) unless @business.employee_memberships.available_for_booking.exists?

        return false
      end

      employee = preferred_employee || assign_employee_for(service, starts_at)
      return false if employee.blank?

      Availability::Slots.public_available?(business: @business, service: service, starts_at: starts_at, employee_membership: employee)
    end

    def assign_employee_for(service, starts_at)
      Bookings::AssignProfessionalService.call(
        business: @business,
        service: service,
        starts_at: starts_at,
        assignment_strategy: assignment_strategy_for_public_booking,
        lock: false,
        online_booking: true
      )
    rescue Bookings::AssignProfessionalService::UnavailableProfessional
      nil
    end

    def assignable_employees_for_service(service)
      employees = @employees_by_service&.fetch(service, nil)
      return employees unless employees.nil?

      employees = available_employees_for_services
      employees = employees.select { |membership| service.employee_membership_ids.include?(membership.id) } if service.employee_membership_ids.any?
      employees
    end

    def single_employee_for_all_services
      return unless @business.team_features_available?

      candidates = @employee_memberships.select do |membership|
        @selected_services.all? { |service| @employees_by_service.fetch(service, []).include?(membership) }
      end
      candidates.one? ? candidates.first : nil
    end

    def professional_step_required?
      return false unless @business.public_booking_allow_professional_selection?
      return false unless @business.team_features_available?
      return false if @single_employee_membership.present?

      @employee_memberships.many?
    end

    def assignment_strategy_for_public_booking
      return Business::PUBLIC_BOOKING_ASSIGNMENT_STRATEGY_DEFAULT if @business.public_booking_allow_professional_selection?

      @business.public_booking_assignment_strategy
    end

    def record_booking_intent_started
      intent = current_booking_intent
      if intent.blank? || intent.service_id != @service.id
        intent = @business.booking_intents.create!(
          service: @service,
          employee_membership: @employee_membership,
          status: "started",
          expires_at: 2.hours.from_now,
          metadata: { source: "public_booking", landing_url: request.original_url }
        )
        session[:booking_intent_id] = intent.id
      elsif intent.employee_membership_id != @employee_membership&.id
        intent.update!(employee_membership: @employee_membership)
      end
      intent
    end

    def current_booking_intent
      intent_id = booking_submission_params[:booking_intent_id].presence || session[:booking_intent_id]
      return if intent_id.blank?

      @business.booking_intents.active.find_by(id: intent_id)
    rescue ActionController::ParameterMissing
      @business.booking_intents.active.find_by(id: session[:booking_intent_id]) if session[:booking_intent_id].present?
    end

    def validate_service_form_answers!(service, raw_answers)
      form = service.service_form
      return unless form&.active?

      answers = (raw_answers || {}).to_h
      missing = form.service_form_questions.select(&:required?).select { |question| answers[question.id.to_s].blank? }
      return if missing.blank?

      raise ArgumentError, "Respondé las preguntas obligatorias: #{missing.map(&:label).to_sentence}"
    end

    def create_service_form_response!(appointment, raw_answers)
      form = appointment.service.service_form
      return unless form&.active?

      answers = (raw_answers || {}).to_h.compact_blank
      return if answers.blank?

      appointment.service_form_responses.create!(
        business: appointment.business,
        customer_profile: appointment.customer_profile,
        service_form: form,
        answers: answers
      )
    end

    def selected_branch_for_booking
      employee_membership = selected_employee_for_booking
      return employee_membership.branch if employee_membership&.branch.present?
      return unless @business.team_features_available? && booking_submission_params[:branch_id].present?

      @business.branches.active.find_by(id: booking_submission_params[:branch_id])
    end

    def bookable_services
      @business.services.active
        .where(visibility_mode: %w[public link_only], public_visible: true)
        .where("name <> '' AND duration_minutes > 0")
    end

    def services_from_public_keys(keys)
      keys = Array(keys).compact_blank.map { |key| key.to_s.strip }.uniq.first(1)
      return [] if keys.blank?

      numeric_ids = keys.select { |key| key.match?(/\A\d+\z/) }.map(&:to_i)
      base = bookable_services
      services = base
        .where(slug: keys)
        .or(base.where(id: numeric_ids))
        .includes(:employee_memberships, :service_availability_rules, service_variants: :pet_size_band, service_resources: :bookable_resource)
        .to_a
      services_by_key = {}
      services.each do |service|
        services_by_key[service.slug] = service
        services_by_key[service.id.to_s] ||= service
      end

      keys.filter_map { |key| services_by_key[key] }.uniq
    end

    def service_from_public_key(key, scope:)
      key = key.to_s.strip
      return if key.blank?

      Array(scope).find { |service| service.slug == key || service.id.to_s == key }
    end

    helper_method def booking_calendar_params(date:, month: @month_date, step: @booking_step, date_window_start: @date_window_start)
      {
        service_ids: @selected_services.map(&:slug),
        service_variant_id: @service_variant&.id,
        extra_ids: @selected_extras.map(&:id),
        date: date,
        month: month,
        step: step,
        date_window_start: date_window_start,
        professional_mode: @professional_mode,
        employee_membership_id: @selected_employee_membership&.id,
        professionals: @selected_professionals_by_service.to_h { |service, membership| [ service.slug, membership&.id ] },
        draft: @booking_draft_token
      }.compact
    end

    def prepare_waitlist_context
      @waitlist_date_options = (Time.zone.today..WAITLIST_DATE_RANGE_DAYS.days.from_now.to_date).to_a
      @waitlist_time_presets = WaitlistEntry::TIME_PRESETS
      @waitlist_preferences = waitlist_preferences_from_params
      @waitlist_available_slots_present = @waitlist_preferences.any? do |preference|
        waitlist_window_has_available_slots?(preference.fetch(:date), preference.fetch(:window))
      end
    end

    def waitlist_preferences_from_params
      raw = params[:waitlist_preferences]
      raw = raw.to_unsafe_h.values if raw.respond_to?(:to_unsafe_h)
      raw = raw.values if raw.is_a?(Hash)
      default_preference = default_waitlist_preference
      return [ default_preference ] if Array(raw).blank?

      raw.filter_map do |attrs|
        attrs = attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h : attrs.to_h
        date = Date.parse(attrs["date"].presence || @date.iso8601)
        next if date < Time.zone.today || date > WAITLIST_DATE_RANGE_DAYS.days.from_now.to_date

        window = WaitlistEntry.normalize_time_window(attrs)
        next if window.blank?

        { date: date, window: window }
      end.presence || [ default_preference ]
    end

    def default_waitlist_preference
      {
        date: @date,
        window: WaitlistEntry.normalize_time_window("night")
      }
    end

    def waitlist_window_has_available_slots?(date, window)
      slots_for_calendar_date(date).any? { |slot| WaitlistEntry.time_window_covers?([ window ], slot) }
    end

    def selected_public_employee(employees)
      return nil unless @business.public_booking_allow_professional_selection?
      return nil if @service.hide_professional_selection?
      selected = employees.find { |membership| membership.id == params[:employee_membership_id].to_i } if params[:employee_membership_id].present?
      return selected if selected.present?
      return employees.first if employees.one?
      return employees.first if @service.require_professional_selection?

      nil
    end

    def fallback_booking_path
      return public_business_path(@business.slug) if booking_submission_params[:service_ids].blank?

      date = Time.zone.parse(booking_submission_params[:starts_at]).to_date rescue Time.zone.today
      new_public_booking_path(
        @business.slug,
        service_ids: booking_submission_params[:service_ids],
        date: date,
        employee_membership_id: booking_submission_params[:employee_membership_id],
        professional_mode: booking_submission_params[:professional_mode],
        professionals: booking_submission_params[:professionals],
        step: "schedule"
      )
    end

    def confirmation_token(appointment)
      appointment.signed_id(expires_in: 30.days, purpose: :public_booking_confirmation)
    end

    def find_confirmation
      return if params[:confirmation].blank?

      appointment = Appointment.find_signed(params[:confirmation], purpose: :public_booking_confirmation)
      appointment if appointment&.business_id == @business.id
    end

    def find_confirmation!
      appointment = Appointment.find_signed!(params.require(:confirmation), purpose: :public_booking_confirmation)
      raise ActiveRecord::RecordNotFound unless appointment.business_id == @business.id

      appointment
    end

    def calendar_payload(appointment)
      starts_at = appointment.starts_at.utc
      ends_at = appointment.ends_at.utc
      [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Cita.pet//Reservas//ES",
        "BEGIN:VEVENT",
        "UID:appointment-#{appointment.id}@#{AppUrl.host}",
        "DTSTAMP:#{Time.current.utc.strftime('%Y%m%dT%H%M%SZ')}",
        "DTSTART:#{starts_at.strftime('%Y%m%dT%H%M%SZ')}",
        "DTEND:#{ends_at.strftime('%Y%m%dT%H%M%SZ')}",
        "SUMMARY:#{ics_escape("#{appointment.service.name} - #{appointment.business.name}")}",
        "LOCATION:#{ics_escape(appointment.business.public_location)}",
        "DESCRIPTION:#{ics_escape("Turno reservado en línea. Estado: #{appointment.status_label}.")}",
        "END:VEVENT",
        "END:VCALENDAR"
      ].join("\r\n")
    end

    def ics_escape(value)
      value.to_s.gsub("\\", "\\\\\\").gsub("\n", "\\n").gsub(",", "\\,").gsub(";", "\\;")
    end
end
