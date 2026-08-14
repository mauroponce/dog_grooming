module Admin
  class ServiceCategoriesController < BaseController
    def create
      attributes = service_category_params
      cover_image = attributes.delete(:cover_image)
      category = @business.service_categories.new(attributes.merge(sort_order: next_sort_order))

      ActiveRecord::Base.transaction do
        category.save!
        attach_cover_image!(category, cover_image) if cover_image.present?
      end

      redirect_to admin_services_path(service_category_id: category.id), notice: "Categoría creada."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admin_services_path, alert: error.record.errors.full_messages.to_sentence
    end

    def update
      attributes = service_category_params
      cover_image = attributes.delete(:cover_image)

      if update_category_with_cover_image(category, attributes, cover_image)
        attach_cover_image!(category, cover_image) if cover_image.present?
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: category_update_streams(category)
          end
          format.html { redirect_to admin_services_path(service_category_id: category.id), notice: "Categoría actualizada." }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: category_update_streams(category, editing: true, sidebar: false),
              status: :unprocessable_entity
          end
          format.html { redirect_to admin_services_path(service_category_id: category.id), alert: category.errors.full_messages.to_sentence }
        end
      end
    end

    def destroy
      services = category.services.to_a
      service_count = services.size
      pack_count = @business.service_packs.where(service_id: services.map(&:id)).count

      ActiveRecord::Base.transaction do
        @business.service_packs.where(service_id: services.map(&:id)).find_each(&:destroy!)
        services.each(&:destroy!)
        category.destroy!
      end

      redirect_to admin_services_path, notice: "Categoría eliminada permanentemente. Se eliminaron #{service_count} servicios y #{pack_count} paquetes."
    rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed
      redirect_to admin_services_path(service_category_id: category.id), alert: "No se pudo eliminar la categoría porque tiene reservas, packs asignados u otros registros vinculados."
    end

    private
      def category
        @category ||= @business.service_categories.find(params[:id])
      end

      def service_category_params
        params.require(:service_category).permit(:name, :cover_image)
      end

      def attach_cover_image!(category, image)
        category.cover_image.attach(
          Storage::UploadAttachable.build(
            image,
            key: Storage::ObjectKeyBuilder.service_category_cover(category, filename: image.original_filename)
          )
        )
        category.save!
      end

      def update_category_with_cover_image(category, attributes, cover_image)
        ActiveRecord::Base.transaction do
          category.update!(attributes)
          attach_cover_image!(category, cover_image) if cover_image.present?
        end
        true
      rescue ActiveRecord::RecordInvalid
        false
      end

      def category_update_streams(category, editing: false, sidebar: true)
        streams = [
          turbo_stream.replace(
            view_context.dom_id(category, :services_category_heading),
            partial: "admin/services/category_heading_editor",
            locals: { category: category, editing: editing }
          )
        ]

        if sidebar
          streams << turbo_stream.replace(
            view_context.dom_id(category, :services_category_sidebar_name),
            partial: "admin/services/category_sidebar_name",
            locals: { category: category }
          )
        end

        streams
      end

      def next_sort_order
        @business.service_categories.maximum(:sort_order).to_i + 1
      end
  end
end
