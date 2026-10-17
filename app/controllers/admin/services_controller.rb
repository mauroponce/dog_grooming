module Admin
  class ServicesController < BaseController
    def index
      @show_extras = params[:panel] == "extras"
      @extras = @business.extras.order(:title) if @show_extras
      @service_query = Services::InboxQuery.new(business: @business, params: params)
      @service_categories = business_service_categories
      @selected_service_category = @service_query.selected_service_category
      @services = services_index_relation.to_a.sort_by { |service| alphabetical_name_key(service.name) }
      @service_monthly_stats = @service_query.monthly_stats_for(@services)
      @services_by_category_name = @services.group_by { |service| service.service_category&.name.presence || service.category_label }
      @service_pack_counts_by_category_id = service_pack_counts_by_category_id
      @new_service = @business.services.new(
        duration_minutes: 60,
        service_category: @selected_service_category || @service_categories.first,
        category: (@selected_service_category || @service_categories.first)&.name || "General",
        active: false,
        visibility_mode: "hidden",
        public_visible: false
      )
      @show_financials = current_user.admin? || current_user.super_admin?

      respond_to do |format|
        format.html
        format.csv do
          send_data @service_query.to_csv,
            filename: "servicios-#{Time.zone.today.iso8601}.csv",
            type: "text/csv; charset=utf-8"
        end
      end
    end

    def new
      @service_categories = business_service_categories
      @employee_memberships = service_employee_memberships
      selected_category = @business.service_categories.active.find_by(id: params[:service_category_id]) || @service_categories.first
      @service = @business.services.new(
        duration_minutes: 60,
        service_category: selected_category,
        category: selected_category&.name || "General",
        active: false,
        visibility_mode: "hidden",
        public_visible: false
      )
      prepare_size_variants(@service)
    end

    def show
      redirect_to edit_admin_service_path(service)
    end

    def generate_description
      unless Ai::GeminiClient.available?
        render json: { error: "Gemini no está configurado. Falta GEMINI_API_KEY." }, status: :service_unavailable
        return
      end

      description = Ai::ServiceDescriptionGenerator.new(
        business: @business,
        service_name: service_description_params[:service_name],
        category_name: service_description_category_name
      ).call

      render json: { description: description }
    rescue ArgumentError => error
      render json: { error: error.message }, status: :unprocessable_entity
    rescue StandardError => error
      Rails.logger.warn("Service description AI failed for business #{@business.id}: #{error.class} - #{error.message}")
      render json: { error: "No pudimos generar la descripción en este momento." }, status: :bad_gateway
    end

    def create
      attributes = service_params
      sync_public_listing_state!(attributes)
      cover_image = attributes.delete(:cover_image)
      service_images = attributes.delete(:service_images)
      @service = @business.services.new(attributes)
      force_hidden_draft = params[:quick].present? ||
        (params[:minimal].present? && !attributes.key?(:active) && !attributes.key?(:visibility_mode) && !attributes.key?(:public_visible))

      if force_hidden_draft
        @service.duration_minutes ||= 60
        @service.active = false
        @service.visibility_mode = "hidden"
        @service.public_visible = false
      end
      if @service.save
        attach_cover_image!(@service, cover_image) if cover_image.present?
        attach_service_images!(@service, service_images)
        sync_service_availability_rules!(@service)
        redirect_to admin_services_path(service_category_id: @service.service_category_id, service_id: @service.id), notice: force_hidden_draft ? "Servicio creado para completar después." : "Servicio creado."
      else
        prepare_size_variants(@service)
        if params[:minimal].present?
          @service_categories = business_service_categories
          @employee_memberships = service_employee_memberships
          flash.now[:alert] = @service.errors.full_messages.to_sentence
          render :new, status: :unprocessable_entity
        else
          redirect_to admin_services_path, alert: @service.errors.full_messages.to_sentence
        end
      end
    end

    def edit
      @service = service
      prepare_size_variants(@service)
      @service_categories = business_service_categories
      @employee_memberships = service_employee_memberships
    end

    def update
      @service = service
      attributes = service_params
      sync_public_listing_state!(attributes)
      cover_image = attributes.delete(:cover_image)
      service_images = attributes.delete(:service_images)
      if @service.update(attributes)
        attach_cover_image!(@service, cover_image) if cover_image.present?
        attach_service_images!(@service, service_images)
        sync_service_availability_rules!(@service)
        redirect_to service_editor_redirect_path(@service), notice: "Servicio actualizado."
      else
        prepare_size_variants(@service)
        @service_categories = business_service_categories
        @employee_memberships = service_employee_memberships
        flash.now[:alert] = @service.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def duplicate
      copy = Services::DuplicateService.new(service: service).call
      redirect_to admin_services_path(service_id: copy.id), notice: "Servicio duplicado. Revisalo antes de publicarlo."
    end

    def destroy_image
      attachment = service.service_images.attachments.find(params[:attachment_id])
      attachment.purge

      redirect_to edit_admin_service_path(service, tab: "images"), notice: "Imagen eliminada."
    end

    def destroy
      service.archive!
      redirect_to admin_services_path, notice: "Servicio archivado."
    end

    def permanently_destroy
      if service.destroy
        redirect_to admin_services_path, notice: "Servicio eliminado permanentemente."
      else
        redirect_to admin_services_path, alert: service.errors.full_messages.to_sentence.presence || "El servicio no se puede eliminar porque tiene información asociada."
      end
    end

    private
      def service
        @service ||= @business.services.find(params[:id])
      end

      def business_service_categories
        categories = @business.service_categories.active.to_a.sort_by { |category| alphabetical_name_key(category.name) }
        return categories if categories.any?

        [ ServiceCategory.find_or_create_for!(business: @business, name: "General", primary_category: true) ]
      end

      def services_index_relation
        relation = @business.services.includes(:service_category, :bookable_resources, :employee_memberships, :service_tags)
        relation = relation.where(service_category_id: @selected_service_category.id) if @selected_service_category.present?
        relation
      end

      def alphabetical_name_key(value)
        I18n.transliterate(value.to_s).downcase
      end

      def service_pack_counts_by_category_id
        category_ids = @service_categories.map(&:id)
        return {} if category_ids.blank?

        @business.service_packs
          .joins(:service)
          .where(services: { service_category_id: category_ids })
          .group("services.service_category_id")
          .count
      end

      def service_employee_memberships
        @business.employee_memberships.available_for_booking.with_attached_profile_photo.includes(user: { profile_photo_attachment: :blob }).order(:sort_order, :name).to_a
      end

      def service_params
        permitted = params.require(:service).permit(
          :name,
          :slug,
          :category,
          :service_category_id,
          :description,
          :includes,
          :before_care,
          :after_care,
          :public_visible,
          :cover_image,
          :duration_minutes,
          :price,
          :pricing_mode,
          :active,
          :visibility_mode,
          :sort_order,
          :popular,
          :deposit_required,
          :deposit_amount,
          :deposit_percentage,
          :payment_account_id,
          :deposit_payment_deadline_minutes,
          :external_payment_link,
          :public_start_interval_minutes,
          :professional_selection_mode,
          :use_advanced_availability,
          :limit_availability_by_date,
          :availability_starts_on,
          :availability_ends_on,
          :follow_up_enabled,
          :recommended_follow_up_days,
          :tags_text,
          :all_employee_memberships,
          bookable_resource_ids: [],
          recommended_service_ids: [],
          employee_membership_ids: [],
          service_images: [],
          service_variants_attributes: [ :id, :pet_size_band_id, :price, :duration_minutes, :active ]
        )
        if permitted.delete(:all_employee_memberships).to_s == "1"
          permitted[:employee_membership_ids] = []
        end
        permitted
      end

      def prepare_size_variants(target_service)
        bands = @business.ensure_default_pet_size_bands!
        existing_band_ids = target_service.service_variants.map(&:pet_size_band_id)
        bands.each do |band|
          next if existing_band_ids.include?(band.id)

          target_service.service_variants.build(
            pet_size_band: band,
            price_cents: target_service.price_cents,
            duration_minutes: target_service.duration_minutes,
            active: true
          )
        end
      end

      def sync_public_listing_state!(attributes)
        return unless attributes.key?(:public_visible)
        return if @service&.archived?

        if ActiveModel::Type::Boolean.new.cast(attributes[:public_visible])
          attributes[:active] = true
          attributes[:visibility_mode] = "public" unless attributes[:visibility_mode] == "link_only"
        else
          attributes[:visibility_mode] = "hidden"
        end
      end

      def service_description_params
        params.permit(:service_name, :service_category_id, :category_name)
      end

      def service_description_category_name
        category = @business.service_categories.active.find_by(id: service_description_params[:service_category_id])
        category&.name.presence || service_description_params[:category_name].to_s.strip
      end

      def attach_cover_image!(service, image)
        service.cover_image.attach(
          Storage::UploadAttachable.build(
            image,
            key: Storage::ObjectKeyBuilder.service_cover(service, filename: image.original_filename)
          )
        )
      end

      def attach_service_images!(service, images)
        Array(images).compact_blank.each do |image|
          attachable = Storage::UploadAttachable.build(
            image,
            key: Storage::ObjectKeyBuilder.service_image(service, filename: image.original_filename)
          )
          attachable[:service_name] = "service_images" if dedicated_service_images_storage_configured?

          service.service_images.attach(
            attachable
          )
        end
      end

      def dedicated_service_images_storage_configured?
        service_images_bucket_configured? &&
          ActiveStorage::Blob.services.fetch(:service_images) { nil }.present?
      end

      def service_images_bucket_configured?
        ENV["CLOUDFLARE_R2_SERVICE_IMAGES_BUCKET"].present? || ENV["SERVICE_IMAGES_BUCKET"].present?
      end

      def service_editor_redirect_path(service)
        return edit_admin_service_path(service) unless params[:return_tab].to_s.in?(%w[basic team images availability])

        edit_admin_service_path(service, tab: params[:return_tab])
      end

      def sync_service_availability_rules!(service)
        return unless params.key?(:service_availability_rules)

        service.service_availability_rules.destroy_all
        return unless service.use_advanced_availability?

        params.fetch(:service_availability_rules, {}).each do |weekday, values|
          next unless weekday.to_i.in?(0..6)

          rule_params = values.permit(:active, intervals: [ :start_time, :end_time ])
          next unless checked_param?(rule_params[:active])

          Array(rule_params.fetch(:intervals, {}).values).each do |interval|
            next if interval[:start_time].blank? || interval[:end_time].blank?

            service.service_availability_rules.create!(
              weekday: weekday,
              active: true,
              start_time: interval[:start_time],
              end_time: interval[:end_time]
            )
          end
        end
      end

      def checked_param?(value)
        Array(value).last.to_s == "1"
      end
  end
end
