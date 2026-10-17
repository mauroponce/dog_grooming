module SuperAdmin
  class CreateBusinessAccount
    Result = Struct.new(:business, :owner, keyword_init: true)
    ARGENTINA_LATITUDE_RANGE = -55.2..-21.7
    ARGENTINA_LONGITUDE_RANGE = -73.7..-53.6

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @params = params.to_h.symbolize_keys
    end

    def call
      validate!

      business = nil
      owner = nil
      User.transaction do
        owner = User.create!(email_address: owner_email, name: owner_name, role: :admin)
        business = owner.create_business!(business_attributes)
        sync_availability_rules!(business)
        create_owner_professional!(business, owner)
        attach_business_images!(business)
      end

      Result.new(business: business, owner: owner)
    end

    private
      attr_reader :params

        def validate!
          raise ArgumentError, "Completá el nombre del centro." if business_name.blank?
          raise ArgumentError, "Completá el nombre del dueño." if owner_name.blank?
          raise ArgumentError, "Completá el email de acceso del dueño." unless owner_email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
        raise ArgumentError, "Completá el teléfono del negocio." if contact_phone.blank?
        raise ArgumentError, "Ese email ya tiene una cuenta." if User.exists?(email_address: owner_email)
        raise ArgumentError, "El slug elegido no es válido." if requested_slug.present? && !Slugs::GenerateUnique.valid?(requested_slug)
        raise ArgumentError, "Ese link público ya está en uso." if requested_slug.present? && !Slugs::GenerateUnique.available?(requested_slug, scope: Business)
        validate_coordinates!
        validate_image_uploads!
      end

      def business_attributes
        {
          name: business_name,
          slug: requested_slug.presence || Slugs::GenerateUnique.call(business_name, scope: Business),
          business_kind: "business",
          billing_enabled: billing_enabled?,
          industry: "dog_grooming",
          contact_phone: contact_phone,
          phone: contact_phone,
          instagram_url: instagram_url,
          custom_domain: params[:custom_domain],
          custom_domain_enabled: custom_domain_enabled?,
          address: address,
          address_details: address_details,
          latitude: latitude,
          longitude: longitude,
          city: city,
          province: province,
          cancellation_notice_hours: 12,
          setup_status: "in_progress",
          onboarding_completed_at: Time.current,
          slogan: slogan,
          preferences: Business::PREFERENCE_DEFAULTS.merge("setup_warnings" => setup_warnings)
        }
      end

      def create_owner_professional!(business, owner)
        business.employee_memberships.create!(
            user: owner,
            name: owner_name,
            first_name: owner_first_name,
            last_name: owner_last_name,
          email_address: owner.email_address,
          phone: business.contact_phone,
          specialty: business.industry_label,
          branch: business.branches.first,
          status: "active",
          invitation_sent_at: Time.current,
          invitation_accepted_at: Time.current,
          invited_by: owner,
          permissions: EmployeeMembership::PERMISSIONS.keys.index_with { true }
        )
      end

      def attach_business_images!(business)
        attach_logo!(business) if logo.present?
      end

      def attach_logo!(business)
        business.logo.attach(
          ::Storage::UploadAttachable.build(
            logo,
            key: ::Storage::ObjectKeyBuilder.business_logo(business, filename: logo.original_filename)
          )
        )
      end

      def validate_image_uploads!
        validate_image_upload!(logo, label: "El logo", max_size: Business::LOGO_MAX_SIZE) if logo.present?
      end

      def validate_image_upload!(upload, label:, max_size:)
        content_type = upload.respond_to?(:content_type) ? upload.content_type.to_s : ""
        size = upload.respond_to?(:size) ? upload.size.to_i : upload.try(:tempfile).try(:size).to_i

        raise ArgumentError, "#{label} debe ser JPG, PNG o WebP." unless content_type.in?(Business::LOGO_CONTENT_TYPES)
        raise ArgumentError, "#{label} no puede superar #{max_size / 1.megabyte} MB." if size > max_size
      end

      def setup_warnings
        [ "Compartir link" ]
      end

      def billing_enabled?
        params.key?(:billing_enabled) ? ActiveModel::Type::Boolean.new.cast(params[:billing_enabled]) : true
      end

      def custom_domain_enabled?
        ActiveModel::Type::Boolean.new.cast(params[:custom_domain_enabled]) || false
      end

        def business_name
          params[:business_name].to_s.strip
        end

        def owner_name
          params[:owner_name].to_s.squish
        end

        def owner_first_name
          owner_name.split.first.presence || "Admin"
        end

        def owner_last_name
          parts = owner_name.split
          parts.drop(1).join(" ").presence || "Principal"
        end

      def owner_email
        params[:owner_email].to_s.strip.downcase
      end

      def contact_phone
        params[:contact_phone].to_s.strip.presence
      end

      def instagram_url
        normalize_instagram_url(params[:instagram_url])
      end

      def normalize_instagram_url(value)
        handle = value.to_s.strip
          .sub(/\Ahttps?:\/\/(www\.)?instagram\.com\//i, "")
          .sub(/\A@/, "")
          .sub(/\/+\z/, "")

        handle.present? ? "https://www.instagram.com/#{handle}" : nil
      end

      def slogan
        params[:slogan].to_s.squish.presence
      end

      def address
        params[:address].to_s.strip.presence
      end

      def address_details
        params[:address_details].to_s.squish.presence
      end

      def city
        params[:city].to_s.strip.presence
      end

      def province
        params[:province].to_s.strip.presence
      end

      def latitude
        @latitude = parse_coordinate(params[:latitude]) unless instance_variable_defined?(:@latitude)
        @latitude
      end

      def longitude
        @longitude = parse_coordinate(params[:longitude]) unless instance_variable_defined?(:@longitude)
        @longitude
      end

      def validate_coordinates!
        latitude_present = params[:latitude].to_s.strip.present?
        longitude_present = params[:longitude].to_s.strip.present?
        return unless latitude_present || longitude_present

        raise ArgumentError, "Elegí una dirección válida de Argentina." if latitude.blank? || longitude.blank?
        raise ArgumentError, "Elegí una dirección válida de Argentina." unless ARGENTINA_LATITUDE_RANGE.cover?(latitude.to_f) && ARGENTINA_LONGITUDE_RANGE.cover?(longitude.to_f)
      end

      def parse_coordinate(value)
        raw_value = value.to_s.tr(",", ".").strip
        return nil if raw_value.blank?

        BigDecimal(raw_value)
      rescue ArgumentError
        nil
      end

      def requested_slug
        @requested_slug ||= Business.slug_for(params[:slug].to_s.strip) if params[:slug].present?
      end

      def sync_availability_rules!(business)
        SuperAdmin::SyncBusinessAvailability.call(business, params[:availability_rules])
      end

      def logo
        params[:logo]
      end
  end
end
