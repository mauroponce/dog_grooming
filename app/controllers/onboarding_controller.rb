class OnboardingController < ApplicationController
  before_action :require_admin!
  before_action :set_business

  def schedule
    @rules = @business.availability_rules.order(:weekday)
  end

  def update_schedule
    @business.transaction do
      @business.update!(params.require(:agenda).permit(:simultaneous_capacity, :arrival_mode)) if params[:agenda].present?
      times = @business.arrival_times.dup
      rules_params.each do |weekday, values|
        times[weekday.to_s] = values[:arrival_times].to_s.split(/[,\s]+/).reject(&:blank?) if values.key?(:arrival_times)
        rule = @business.availability_rules.find_by!(weekday: weekday)
        rule.update!(
          active: values[:active] == "1",
          start_time: values[:start_time],
          end_time: values[:end_time]
        )
      end
      @business.update!(arrival_times: times)
    end

    redirect_to onboarding_service_path
  rescue ActiveRecord::RecordInvalid => error
    @rules = @business.availability_rules.order(:weekday)
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :schedule, status: :unprocessable_entity
  end

  def service
    prepare_service_step
  end

  def create_service
    prepare_service_step
    selected_templates = selected_service_templates
    custom_attrs = custom_service_params

    if selected_templates.blank? && custom_attrs[:name].blank? && @business.services.none?
      @service.assign_attributes(custom_attrs)
      flash.now[:alert] = "Elegí al menos un servicio sugerido o cargá un servicio propio."
      render :service, status: :unprocessable_entity
      return
    end

    @business.transaction do
      selected_templates.each do |template|
        @business.services.find_or_create_by!(name: template.fetch(:name)) { |service| service.assign_attributes(template) }
      end
      @business.services.create!(custom_attrs) if custom_attrs[:name].present?
      @business.update!(onboarding_completed_at: Time.current)
    end

    redirect_to onboarding_done_path
  rescue ActiveRecord::RecordInvalid => error
    @service = error.record
    @templates = @business.service_templates
    flash.now[:alert] = @service.errors.full_messages.to_sentence
    render :service, status: :unprocessable_entity
  end

  def done
  end

  private
    def require_admin!
      redirect_to root_path, alert: "No autorizado" unless current_user&.admin?
    end

    def set_business
      @business = current_user.business
    end

    def rules_params
      params.fetch(:rules, {}).each_with_object({}) do |(weekday, values), sanitized|
        next unless weekday.to_i.in?(0..6)

        sanitized[weekday] = values.permit(:active, :start_time, :end_time, :arrival_times).to_h
      end
    end

    def prepare_service_step
      @templates = @business.service_templates
      default_template = @templates.first || { category: @business.industry_category, duration_minutes: 60 }
      @service = @business.services.new(duration_minutes: default_template[:duration_minutes], category: default_template[:category])
    end

    def selected_service_templates
      indexes = Array(params[:service_template_indexes]).filter_map { |index| Integer(index, exception: false) }.uniq
      indexes.filter_map { |index| @templates[index] }
    end

    def custom_service_params
      params.fetch(:service, ActionController::Parameters.new)
        .permit(:name, :category, :description, :duration_minutes, :price)
        .to_h
        .symbolize_keys
    end
end
