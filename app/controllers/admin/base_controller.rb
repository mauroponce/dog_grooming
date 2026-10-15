module Admin
  class BaseController < ApplicationController
    AREA_POLICIES = {
      "calendar" => :appointments?,
      "availability_blocks" => :availability?,
      "appointments" => :appointments?,
      "home" => :dashboard?,
      "home_opportunities" => :dashboard?,
      "dashboard" => :dashboard?,
      "assistant_messages" => :dashboard?,
      "billing" => :billing?,
      "services" => :services?,
      "extras" => :services?,
      "customer_profiles" => :customers?,
      "client_notes" => :customers?,
      "customer_reminders" => :customers?,
      "service_categories" => :services?,
      "waitlist_entries" => :waitlist?,
      "employee_memberships" => :employees?,
      "settings" => :settings?,
      "tutorials" => :tutorials?,
      "non_working_periods" => :settings?,
      "notifications" => :dashboard?,
      "mercado_pago_connections" => :settings?,
      "whatsapp_connections" => :settings?
    }.freeze

    before_action :require_staff!
    before_action :set_business
    before_action :set_notification_center
    before_action :require_onboarding!
    before_action :require_business_access!
    before_action :require_billing_permissions!
    before_action :authorize_admin_area!

    helper_method :current_employee_membership

    private
      def require_staff!
        unless authenticated?
          request_authentication
          return
        end

        redirect_to root_path, alert: "No autorizado" unless current_user&.admin? || current_user&.employee?
      end

      def set_business
        @business = current_user.primary_business
        redirect_to root_path, alert: "No tenés un negocio asociado." unless @business
      end

      def set_notification_center
        return unless @business

        @notification_center = Admin::NotificationCenter.new(business: @business, current_user: current_user)
      end

      def current_employee_membership
        return unless current_user&.employee? && @business

        @current_employee_membership ||= current_user.employee_membership_for(@business)
      end

      def customer_portal_url_for(customer_profile)
        return if customer_profile.blank? || @business&.slug.blank?

        PublicUrls.url(
          :customer_portal_profile_access,
          @business,
          customer_profile.customer_portal_short_token.presence || customer_profile.customer_portal_token,
          host: current_public_link_host,
          protocol: current_public_link_protocol
        )
      end

      def current_public_link_host
        forwarded_host = request.headers.fetch("X-Forwarded-Host", nil).to_s.split(",").first&.strip
        forwarded_host.presence || request.host_with_port.presence || AppUrl.host
      end

      def current_public_link_protocol
        forwarded_protocol = request.headers.fetch("X-Forwarded-Proto", nil).to_s.split(",").first&.strip
        protocol = forwarded_protocol.presence || request.protocol.presence || AppUrl.protocol

        "#{protocol.to_s.delete_suffix("://")}://"
      end

      def customer_summary_payload_for(customer_profile)
        return default_customer_summary_payload unless customer_profile

        relation = policy_scope(@business.appointments).where(customer_profile: customer_profile)
        billable_relation = relation.where.not(status: Appointment.statuses.values_at("canceled", "no_show", "expired"))
        presenter = Customers::ProfilePresenter.new(
          customer: customer_profile,
          business: @business,
          appointments_scope: relation,
          current_user: current_user
        )
        status_chip = presenter.status_chips.first

        {
          appointmentsCount: relation.count,
          totalSales: billable_relation.sum(Arel.sql("COALESCE(final_price_cents, base_price_cents, 0)")) / 100,
          noShowCount: relation.where(status: Appointment.statuses["no_show"]).count,
          statusLabel: status_chip&.label || "Cliente",
          statusTone: status_chip&.tone || "zinc"
        }
      end

      def default_customer_summary_payload
        {
          appointmentsCount: 0,
          totalSales: 0,
          noShowCount: 0,
          statusLabel: "Cliente",
          statusTone: "zinc"
        }
      end

      def appointment_detail_payload(appointment)
        receipt_visible = appointment.deposit_receipt.attached? && policy(appointment).review_deposit?
        receipt_previewable = receipt_visible && appointment.deposit_receipt.content_type.to_s.start_with?("image/")

        {
          employeeName: appointment.employee_membership&.display_name || @business.name,
          ownerName: appointment.customer_name,
          petId: appointment.pet_id&.to_s,
          petName: appointment.pet&.name,
          petBreed: appointment.pet&.breed,
          petSex: appointment.pet&.sex_label,
          petNotes: appointment.pet&.notes,
          endsAt: appointment.ends_at&.iso8601,
          totalPrice: appointment.current_total_price_cents / 100,
          branchName: appointment.branch&.name,
          resourceName: appointment.bookable_resource&.name,
          sourceLabel: appointment.source_label,
          createdAt: appointment.created_at&.iso8601,
          confirmedAt: appointment.confirmed_at&.iso8601,
          internalNotes: appointment.internal_notes,
          customerComment: appointment.customer_notes.presence || (appointment.public_booking? ? appointment.notes : nil),
          depositStatus: appointment.deposit_status,
          depositStatusLabel: appointment.deposit_status_label,
          depositRejectionReason: appointment.deposit_rejection_reason,
          depositReceiptUrl: receipt_visible ? download_receipt_admin_appointment_path(appointment) : nil,
          depositReceiptPreviewUrl: receipt_previewable ? rails_blob_path(appointment.deposit_receipt, disposition: "inline") : nil,
          canceledAt: appointment.canceled_at&.iso8601,
          canceledByLabel: appointment.canceled? ? appointment.cancellation_actor_label : nil,
          cancellationReason: appointment.cancellation_reason
        }
      end

      def admin_appointment_status_label(status)
        return "Seña pendiente de aprobación" if status.to_s == "pending_deposit_review"

        Appointment.status_label(status)
      end

      def professional_change_available?(appointment)
        return false if appointment.terminal_status?
        return false unless policy(appointment).update?

        @professional_change_available ||= @business.employee_memberships.available_for_booking.exists?
      end

      def require_onboarding!
        redirect_to onboarding_schedule_path unless @business&.onboarding_complete?
      end

      def require_business_access!
        return if @business&.access_active? || controller_name == "billing"
        if current_user&.employee?
          redirect_to new_session_path, alert: "La cuenta no está activa. Pedile al administrador del negocio que revise la facturación."
          return
        end

        redirect_to root_path, alert: "La cuenta está bloqueada o el período de prueba venció."
      end

      def require_billing_permissions!
        return unless @business&.billing_restricted?
        return if billing_restricted_action_allowed?

        redirect_to root_path, alert: "Tus reservas online están pausadas temporalmente."
      end

      def billing_restricted_action_allowed?
        allowed = {
          "appointments" => %w[create confirm approve_deposit cancel reject_deposit download_receipt upload_receipt finalize],
          "customer_profiles" => %w[index show autocomplete],
          "client_notes" => %w[create],
          "customer_reminders" => %w[create resolve],
          "employee_memberships" => %w[index show],
          "notifications" => %w[mark_all_read mark_read destroy],
          "profiles" => %w[edit update destroy_photo],
          "billing" => :all
        }
        actions = allowed[controller_name]
        actions == :all || Array(actions).include?(action_name)
      end

      def authorize_admin_area!
        return if controller_name == "profiles"
        if controller_name == "billing" && !@business.billing_enabled?
          redirect_to admin_calendar_path, alert: "Esta cuenta no tiene facturación activa."
          return
        end

        query = AREA_POLICIES.fetch(controller_name)
        authorize @business, query
      end
  end
end
