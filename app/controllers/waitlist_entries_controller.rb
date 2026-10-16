class WaitlistEntriesController < ApplicationController
  allow_unauthenticated_access

  before_action :set_business

  def create
    validate_contact_details!
    services = selected_services
    preferences = selected_preferences
    raise ActiveRecord::RecordNotFound, "Seleccioná al menos un servicio." if services.blank?
    raise ArgumentError, "Seleccioná al menos una fecha y franja horaria." if preferences.blank?

    created_entries = []
    @business.transaction do
      services.each do |service|
        preferences.each do |preference|
          created_entries << @business.waitlist_entries.create!(
            service: service,
            client_name: waitlist_params[:client_name],
            client_phone: waitlist_params[:client_phone],
            email: waitlist_params[:email],
            desired_date: preference.fetch(:date),
            preferred_weekdays: [ preference.fetch(:date).wday ],
            preferred_time_windows: [ preference.fetch(:window) ],
            notes: waitlist_params[:notes],
            source: "public_page",
            status: "waiting"
          )
        end
      end
    end

    redirect_to new_public_booking_path(
      @business.slug,
      service_ids: services.map(&:slug),
      step: "schedule",
      date: created_entries.first.desired_date
    ), notice: "Te sumamos a la lista de espera."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, Date::Error, ArgumentError => error
    redirect_back fallback_location: public_business_path(@business.slug), alert: error.message
  end

  private
    def set_business
      @business = Business.find_by_custom_domain(request.host) || Business.find_by!(slug: params[:slug])
    end

    def waitlist_params
      params.require(:waitlist_entry).permit(
        :service_id,
        :client_name,
        :client_phone,
        :email,
        :desired_date,
        :notes,
        service_ids: [],
        preferred_weekdays: [],
        preferred_time_windows: [],
        preferences: [ :date, :period, :label, :start_time, :end_time ]
      )
    end

    def selected_services
      keys = Array(waitlist_params[:service_ids]).compact_blank
      keys << waitlist_params[:service_id] if waitlist_params[:service_id].present?
      keys = keys.map { |key| key.to_s.strip }.uniq
      return [] if keys.blank?

      numeric_ids = keys.select { |key| key.match?(/\A\d+\z/) }.map(&:to_i)
      base = @business.services.active
      services = base.where(slug: keys).or(base.where(id: numeric_ids)).to_a
      services_by_key = {}
      services.each do |service|
        services_by_key[service.slug] = service
        services_by_key[service.id.to_s] ||= service
      end

      keys.filter_map { |key| services_by_key[key] }.uniq
    end

    def validate_contact_details!
      raise ArgumentError, "Completá tu teléfono." if waitlist_params[:client_phone].blank?
      raise ArgumentError, "Completá tu email." if waitlist_params[:email].blank?
      raise ArgumentError, "Ingresá un email válido." unless waitlist_params[:email].to_s.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def selected_preferences
      raw_preferences = Array(waitlist_params[:preferences]).presence || legacy_preferences
      raw_preferences.filter_map do |attrs|
        attrs = attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h : attrs.to_h
        date = Date.parse(attrs["date"].presence || waitlist_params[:desired_date].to_s)
        window = WaitlistEntry.normalize_time_window(attrs)
        next if window.blank?

        { date: date, window: window }
      end.uniq { |preference| [ preference.fetch(:date), preference.fetch(:window).fetch("start_time"), preference.fetch(:window).fetch("end_time") ] }
    end

    def legacy_preferences
      desired_date = waitlist_params[:desired_date].presence || Time.zone.today.iso8601
      windows = Array(waitlist_params[:preferred_time_windows]).compact_blank
      windows = [ "any" ] if windows.blank?
      windows.map { |window| { "date" => desired_date, "period" => window } }
    end
end
