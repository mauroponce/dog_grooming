module CustomerPortal
  class BaseController < ApplicationController
    allow_unauthenticated_access

    before_action :set_public_business

    helper_method :current_customer_portal_contact_label, :current_customer_portal_email, :customer_portal_authenticated?

    private
      def set_public_business
        @business = Business.find_by_custom_domain(request.host) || Business.find_by(slug: params[:slug])
        redirect_to root_path, alert: "La página que buscás no existe." if @business.blank?
        redirect_to root_path, alert: "La página que buscás no está disponible." if @business.present? && !@business.access_active?
      end

      def require_customer_portal_session!
        return if customer_portal_authenticated?

        redirect_to customer_portal_entry_path(@business.slug), alert: "Pedí un nuevo enlace para ver tus turnos."
      end

      def customer_portal_authenticated?
        return false if @business.blank?
        return false unless session[:customer_portal_business_id].to_i == @business.id
        return false if current_customer_portal_email.blank? && current_customer_portal_phone.blank? && current_customer_portal_profile_id.blank?
        return false if customer_portal_expires_at.blank? || customer_portal_expires_at <= Time.current

        customer_profiles_for_session.exists?
      end

      def start_customer_portal_session!(email: nil, phone: nil, customer_profile: nil)
        session[:customer_portal_business_id] = @business.id
        session[:customer_portal_customer_profile_id] = customer_profile&.id
        session[:customer_portal_email] = normalize_email(email || customer_profile&.normalized_email)
        session[:customer_portal_phone] = normalize_phone(phone || customer_profile&.normalized_phone)
        session[:customer_portal_expires_at] = 7.days.from_now.to_i
        reset_customer_portal_memo!
      end

      def reset_customer_portal_session!
        session.delete(:customer_portal_business_id)
        session.delete(:customer_portal_customer_profile_id)
        session.delete(:customer_portal_email)
        session.delete(:customer_portal_phone)
        session.delete(:customer_portal_expires_at)
        reset_customer_portal_memo!
      end

      def current_customer_portal_email
        normalize_email(session[:customer_portal_email])
      end

      def current_customer_portal_phone
        normalize_phone(session[:customer_portal_phone])
      end

      def current_customer_portal_contact_label
        current_customer_portal_email.presence ||
          current_customer_portal_phone.presence ||
          customer_profiles_for_session.first&.name
      end

      def current_customer_portal_profile_id
        value = session[:customer_portal_customer_profile_id].to_i
        value.positive? ? value : nil
      end

      def customer_profiles_for_session
        @customer_profiles_for_session ||= begin
          if current_customer_portal_profile_id.present?
            @business.customer_profiles.where(id: current_customer_portal_profile_id)
          elsif current_customer_portal_email.present?
            @business.customer_profiles.where(normalized_email: current_customer_portal_email)
          elsif current_customer_portal_phone.present?
            @business.customer_profiles.where(normalized_phone: phone_lookup_values(current_customer_portal_phone))
          else
            @business.customer_profiles.none
          end
        end
      end

      def customer_profile_ids_for_session
        @customer_profile_ids_for_session ||= customer_profiles_for_session.pluck(:id)
      end

      def portal_appointments_scope
        @business.appointments.where(customer_profile_id: customer_profile_ids_for_session)
      end

      def customer_portal_expires_at
        timestamp = session[:customer_portal_expires_at].to_i
        return if timestamp <= 0

        Time.zone.at(timestamp)
      end

      def normalize_email(value)
        value.to_s.strip.downcase.presence
      end

      def normalize_phone(value)
        PhoneNumber.normalize(value).presence
      end

      def phone_lookup_values(value)
        normalized = PhoneNormalizer.normalize(value)
        [ normalize_phone(value), normalized, normalized.present? ? "+#{normalized}" : nil ].compact_blank.uniq
      end

      def reset_customer_portal_memo!
        @customer_profiles_for_session = nil
        @customer_profile_ids_for_session = nil
      end
  end
end
