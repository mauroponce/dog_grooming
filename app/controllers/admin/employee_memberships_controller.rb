module Admin
  class EmployeeMembershipsController < BaseController
    def index
      prepare_index_context
    end

    def new
      @employee = @business.employee_memberships.new(
        calendar_color: EmployeeMembership::CALENDAR_COLORS.keys.first,
        can_receive_appointments: true
      )
      @employee.access_level = "medium"
      prepare_form_collections
    end

    def create
      prepare_form_collections
      @employee = @business.employee_memberships.new(employee_params)
      @employee.branch = default_branch
      @employee.email_address = @employee.email_address.to_s.strip.downcase
      @employee.access_level = "medium"
      @employee.calendar_color ||= EmployeeMembership::CALENDAR_COLORS.keys.first

      if User.exists?(email_address: @employee.email_address)
        @employee.errors.add(:email_address, "ya pertenece a un usuario existente")
        render :new, status: :unprocessable_entity
      elsif @employee.save
        sync_employee_services!(@employee)
        sync_employee_schedule!(@employee)
        @employee.update!(
          status: "active",
          invited_by: current_user,
          invitation_sent_at: nil,
          invitation_expires_at: nil,
          invitation_token_digest: nil,
          invitation_accepted_at: nil
        )
        redirect_to admin_employee_memberships_path, notice: "Miembro agregado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @employee = employee
      prepare_form_collections
      load_employee_appointments
    end

    def update
      @employee = employee
      @employee.assign_attributes(employee_params)
      @employee.branch ||= default_branch
      @employee.permission_keys = permission_keys

      if email_taken_by_another_user?(@employee)
        @employee.errors.add(:email_address, "ya pertenece a otro usuario existente")
        prepare_form_collections
        load_employee_appointments
        render :edit, status: :unprocessable_entity
      else
        EmployeeMembership.transaction do
          @employee.save!
          sync_linked_user_email!(@employee)
          sync_employee_services!(@employee)
          sync_employee_schedule!(@employee)
          sync_linked_user_profile_photo!(@employee)
        end
        redirect_to admin_employee_memberships_path, notice: "Empleado actualizado."
      end
    rescue ActiveRecord::RecordInvalid
      prepare_form_collections
      load_employee_appointments
      render :edit, status: :unprocessable_entity
    end

    def update_role
      @employee = employee
      if @employee.owner_profile?
        redirect_to admin_employee_memberships_path, alert: "El propietario del espacio de trabajo siempre tiene acceso total."
        return
      end

      @employee.access_level = role_params[:access_level]

      if @employee.save
        redirect_to admin_employee_memberships_path, notice: "Rol de permisos actualizado."
      else
        redirect_to admin_employee_memberships_path, alert: @employee.errors.full_messages.to_sentence
      end
    end

    def destroy
      pending_invitation = employee.pending?
      employee.revoke!
      redirect_to admin_employee_memberships_path, notice: pending_invitation ? "Invitación cancelada." : "Empleado desactivado."
    end

    def permanently_destroy
      if employee.owner_profile?
        redirect_to admin_employee_memberships_path, alert: "El propietario del espacio de trabajo no se puede eliminar."
        return
      end

      employee.destroy!
      redirect_to admin_employee_memberships_path, notice: "Miembro eliminado."
    end

    def resend
      employee.reinvite!(invited_by: current_user)
      redirect_to admin_employee_memberships_path, notice: "Invitación reenviada."
    end

    def reactivate
      employee.update!(status: "active", archived_at: nil)
      redirect_to admin_employee_memberships_path, notice: "Empleado reactivado."
    end

    private
      def prepare_index_context
        @team_query = Team::ProfessionalsQuery.new(business: @business, params: ActionController::Parameters.new)
        @employees = @team_query.employees
      end

      def employee
        @employee ||= @business.employee_memberships.find(params[:id])
      end

      def prepare_form_collections
        @services = @business.services.active.order(:category, :sort_order, :name)
      end

      def load_employee_appointments
        @employee_appointments_pagy, appointments = pagy_collection(
          policy_scope(@business.appointments)
            .where(employee_membership: @employee)
            .includes(:service, { canceled_by_user: :employee_memberships })
            .order(starts_at: :desc, id: :desc),
          limit: 20
        )
        @employee_appointments = appointments.to_a
      end

      def default_branch
        @business.branches.active.order(:created_at).first
      end

      def employee_params
        params.require(:employee_membership).permit(:first_name, :last_name, :name, :email_address, :phone, :additional_phone, :calendar_color, :profile_photo, :specialty, :sort_order, :can_receive_appointments)
      end

      def email_taken_by_another_user?(employee)
        email = employee.email_address.to_s.strip.downcase
        return false if email.blank?

        User.where(email_address: email).where.not(id: employee.user_id).exists?
      end

      def role_params
        params.require(:employee_membership).permit(:access_level)
      end

      def permission_keys
        values = params.fetch(:employee_membership, {}).fetch(:permission_keys, nil)
        return values if values.present?

        EmployeeMembership::DEFAULT_PERMISSIONS
      end

      def sync_employee_services!(employee)
        return unless params.fetch(:employee_membership, {}).key?(:service_ids)

        requested_ids = Array(params[:employee_membership][:service_ids]).reject(&:blank?)
        employee.service_ids = @business.services.where(id: requested_ids).ids
      end

      def sync_employee_schedule!(employee)
        return if params[:employee_availability_rules].blank?

        employee.ensure_availability_rules!
        params.fetch(:employee_availability_rules, {}).each do |weekday, values|
          next unless weekday.to_i.in?(0..6)

          rule_params = values.permit(:active, :start_time, :end_time)
          employee.employee_availability_rules.find_by!(weekday: weekday).update!(
            active: rule_params[:active] == "1",
            start_time: rule_params[:start_time],
            end_time: rule_params[:end_time],
            inherits_business_hours: false
          )
        end
      end

      def sync_linked_user_profile_photo!(employee)
        return unless params.fetch(:employee_membership, {}).key?(:profile_photo)
        return unless employee.user&.persisted?
        return unless employee.profile_photo.attached?

        employee.user.profile_photo.attach(employee.profile_photo.blob)
      end

      def sync_linked_user_email!(employee)
        return unless employee.user&.persisted?
        return if employee.user.email_address == employee.email_address

        employee.user.update!(email_address: employee.email_address)
      end
  end
end
