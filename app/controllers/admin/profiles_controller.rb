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

    private
      def profile_params
        attributes = params.require(:user).permit(:name, :phone, :profile_photo, :password, :password_confirmation)
        if attributes[:password].blank?
          attributes.delete(:password)
          attributes.delete(:password_confirmation)
        end
        attributes
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
  end
end
