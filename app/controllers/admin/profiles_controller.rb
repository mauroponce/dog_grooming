module Admin
  class ProfilesController < BaseController
    def edit
      @user = current_user
    end

    def update
      @user = current_user
      attributes = profile_params
      if @user.update(attributes)
        sync_linked_membership!(profile_photo_changed: attributes.key?(:profile_photo))
        redirect_to edit_admin_profile_path, notice: "Perfil actualizado."
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy_photo
      @user = current_user
      attachment = @user.profile_photo_attachment

      unless attachment
        redirect_to edit_admin_profile_path, alert: "No hay una foto de perfil para eliminar."
        return
      end

      purge_linked_profile_photos!(attachment.blob_id)
      @user.profile_photo.purge

      redirect_to edit_admin_profile_path, notice: "Foto de perfil eliminada."
    rescue ActiveStorage::Error => error
      redirect_to edit_admin_profile_path, alert: "No pudimos eliminar la foto de perfil: #{error.message}"
    end

    private
      def profile_params
        params.require(:user).permit(:name, :phone, :profile_photo)
      end

      def sync_linked_membership!(profile_photo_changed:)
        business = @business || @user.business
        memberships = @user.employee_memberships
        memberships = memberships.where(business: business) if business.present?

        memberships.find_each do |membership|
          membership.name = @user.name if @user.name.present?
          if profile_photo_changed && @user.profile_photo.attached?
            membership.profile_photo.attach(@user.profile_photo.blob)
          end
          membership.save! if membership.changed? || membership.profile_photo.attachment&.new_record?
        end
      end

      def purge_linked_profile_photos!(blob_id)
        @user.employee_memberships.includes(profile_photo_attachment: :blob).find_each do |membership|
          next unless membership.profile_photo_attachment&.blob_id == blob_id

          membership.profile_photo.purge
        end
      end
  end
end
