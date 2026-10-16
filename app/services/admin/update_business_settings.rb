module Admin
  class UpdateBusinessSettings
    ARGENTINA_LATITUDE_RANGE = -55.2..-21.7
    ARGENTINA_LONGITUDE_RANGE = -73.7..-53.6

    def self.call(business, params)
      new(business, params).call
    end

    def initialize(business, params)
      @business = business
      @params = params.to_h.symbolize_keys
    end

    def call
      validate!

      Business.transaction do
        owner.update!(email_address: owner_email, name: owner_name) if owner.email_address != owner_email || owner.name != owner_name
        business.update!(business_attributes)
        sync_primary_branch_location!
        sync_owner_professional!
        attach_business_images!
      end

      business
    end

    private
      attr_reader :business, :params

      def owner
        business.owner
      end

      def validate!
        raise ArgumentError, "Completá el nombre del centro." if business_name.blank?
        raise ArgumentError, "Completá el nombre del dueño." if owner_name.blank?
        raise ArgumentError, "Completá el email de acceso del dueño." unless owner_email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
        raise ArgumentError, "Completá el teléfono del negocio." if contact_phone.blank?
        raise ArgumentError, "Ese email ya tiene una cuenta." if User.where(email_address: owner_email).where.not(id: owner.id).exists?
        raise ArgumentError, "El slug elegido no es válido." unless Slugs::GenerateUnique.valid?(requested_slug)
        raise ArgumentError, "Ese link público ya está en uso." unless Slugs::GenerateUnique.available?(requested_slug, scope: Business, current_record: business)

        validate_coordinates!
        validate_image_uploads!
      end

      def business_attributes
        {
          name: business_name,
          slug: requested_slug,
          contact_phone: contact_phone,
          phone: contact_phone,
          instagram_url: instagram_url,
          address: address,
          address_details: address_details,
          latitude: latitude,
          longitude: longitude,
          city: city,
          province: province,
          neighborhood: neighborhood,
          slogan: slogan,
          public_site_mode: public_site_mode,
          public_custom_css: public_custom_css,
          public_custom_html: public_custom_html,
          public_category_custom_html: public_category_custom_html,
          ai_context: ai_context
        }
      end

      def sync_primary_branch_location!
        branch = business.branches.find_or_initialize_by(name: "Principal")
        branch.assign_attributes(
          address: business.address,
          address_details: business.address_details,
          city: business.city,
          province: business.province,
          neighborhood: business.neighborhood,
          latitude: business.latitude,
          longitude: business.longitude,
          phone: business.contact_phone
        )
        branch.save!
      end

      def sync_owner_professional!
        membership = business.employee_memberships.find_or_initialize_by(user: owner)
        membership.assign_attributes(
          name: owner_name,
          first_name: owner_first_name,
          last_name: owner_last_name,
          email_address: owner.email_address,
          phone: business.contact_phone,
          specialty: business.industry_label,
          branch: membership.branch || business.branches.first,
          status: "active",
          invitation_sent_at: membership.invitation_sent_at || Time.current,
          invitation_accepted_at: membership.invitation_accepted_at || Time.current,
          invited_by: membership.invited_by || owner,
          permissions: membership.permissions.presence || EmployeeMembership::PERMISSIONS.keys.index_with { true }
        )
        membership.save!
      end

      def attach_business_images!
        attach_logo! if logo.present?
      end

      def attach_logo!
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

      def public_site_mode
        params[:public_site_mode].presence_in(Business::PUBLIC_SITE_MODES.keys) || business.public_site_mode
      end

      def public_custom_css
        params[:public_custom_css].to_s.strip.presence
      end

      def public_custom_html
        params[:public_custom_html].to_s.strip.presence
      end

      def public_category_custom_html
        params[:public_category_custom_html].to_s.strip.presence
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

      def neighborhood
        params[:neighborhood].to_s.strip.presence
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
        @requested_slug ||= Business.slug_for(params[:slug].presence || business_name)
      end

      def ai_context
        [
          "Cuenta comercial de Cita.pet actualizada desde admin.",
          instagram_url.present? ? "Instagram del negocio: #{instagram_url}." : nil,
          "Las alertas operativas se envían por email al dueño."
        ].compact.join("\n")
      end

      def logo
        params[:logo]
      end
  end
end
