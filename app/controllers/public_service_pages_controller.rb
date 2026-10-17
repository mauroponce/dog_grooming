class PublicServicePagesController < ApplicationController
  allow_unauthenticated_access

  before_action :set_business

  def index
    @services = @business.services.publicly_bookable.includes(:service_category).order(:category, :sort_order, :name)
    @landing = ::Public::BusinessLandingPresenter.new(business: @business, params: params, host: request.host)
  end

  def show
    @service = @business.services.publicly_accessible.find_by!(slug: params[:service_slug])
    redirect_to PublicUrls.path(
      :short_service,
      @business,
      @service.slug,
      **request.query_parameters.except("date", "service_id"),
      use_custom_domain: custom_domain_request_for?(@business)
    ), status: :moved_permanently
  rescue ActiveRecord::RecordNotFound
    redirect_to public_business_path(@business.slug), alert: "El servicio no está disponible."
  end

  def category
    @category = @business.service_categories.active.find_by!(slug: params[:category_slug])
    @services = @business.services.publicly_bookable
      .where(service_category: @category)
      .includes(:service_category, :service_tags, cover_image_attachment: :blob)
      .order(:sort_order, :name)
      .to_a
    raise ActiveRecord::RecordNotFound if @services.blank?

    unless @business.full_website_mode?
      redirect_to public_business_path(@business.slug), alert: "Esta página está disponible en el sitio web completo." and return
    end

    @landing = ::Public::BusinessLandingPresenter.new(business: @business, params: params, host: request.host)
  rescue ActiveRecord::RecordNotFound
    redirect_to public_business_path(@business.slug), alert: "La categoría no está disponible."
  end

  private
    def set_business
      @business = Business.find_by_custom_domain(request.host) || Business.find_by(slug: params[:slug])
      redirect_to root_path, alert: "La página que buscás no existe." if @business.blank?
      redirect_to root_path, alert: "La página que buscás no está disponible." if @business.present? && !@business.access_active?
    end
end
