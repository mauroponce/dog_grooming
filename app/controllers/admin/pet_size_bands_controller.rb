module Admin
  class PetSizeBandsController < BaseController
    def edit
      @pet_size_bands = @business.ensure_default_pet_size_bands!
    end

    def update
      attributes_by_id = pet_size_bands_params.to_h
      bands = @business.pet_size_bands.ordered.to_a

      @business.transaction do
        bands.each do |band|
          attributes = attributes_by_id.fetch(band.id.to_s) { raise ActiveRecord::RecordNotFound }
          band.update!(attributes)
        end
        validate_ranges!(bands)
      end

      redirect_to edit_admin_pet_size_bands_path, notice: "Rangos de mascota actualizados."
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      @pet_size_bands = @business.pet_size_bands.ordered
      flash.now[:alert] = error.message
      render :edit, status: :unprocessable_entity
    end

    private
      def pet_size_bands_params
        params.require(:pet_size_bands).to_unsafe_h.transform_values do |attributes|
          ActionController::Parameters.new(attributes).permit(:name, :minimum_weight_kg, :maximum_weight_kg)
        end
      end

      def validate_ranges!(bands)
        bands.sort_by(&:position).each_cons(2) do |previous, following|
          next if previous.maximum_weight_kg.present? && following.minimum_weight_kg > previous.maximum_weight_kg

          raise ArgumentError, "Los rangos deben estar ordenados y no pueden superponerse."
        end
      end
  end
end
