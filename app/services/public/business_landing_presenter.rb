module Public
  class BusinessLandingPresenter
    include Rails.application.routes.url_helpers

    TRACKING_KEYS = %w[src source medium campaign clid utm_source utm_medium utm_campaign utm_content utm_term].freeze
    LandingSlot = Struct.new(:service, :starts_at, :employee_membership, keyword_init: true)
    GalleryPhoto = Struct.new(:file, keyword_init: true)

    attr_reader :business, :params, :service

    def initialize(business:, params: {}, service: nil, host: nil)
      @business = business
      @params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      @service = service
      @use_custom_domain = Business.normalize_custom_domain(host) == business.custom_domain
    end

    def services
      @services ||= business.services.publicly_bookable.with_attached_cover_image.includes(:service_tags).order(:category, :sort_order, :name).to_a
    end

    def featured_services
      @featured_services ||= services.first(6)
    end

    def categories
      @categories ||= begin
        category_ids = services.filter_map(&:service_category_id).uniq
        business.service_categories.active.where(id: category_ids).ordered.with_attached_cover_image.to_a
      end
    end

    def services_for_category(category)
      services.select { |candidate| candidate.service_category_id == category.id }
    end

    def related_services
      return [] if service.blank?

      services.reject { |candidate| candidate.id == service.id }.select { |candidate| candidate.category == service.category }.first(3).presence ||
        services.reject { |candidate| candidate.id == service.id }.first(3)
    end

    def next_available_slots(limit: 3, for_service: service)
      return [] unless show_next_slots? && business.booking_available?

      cache_key = [ limit, for_service&.id ]
      @next_available_slots ||= {}
      @next_available_slots[cache_key] ||= build_next_available_slots(limit:, for_service:)
    end

    def gallery_photos(limit: 8)
      return [] unless business.public_show_gallery?

      @gallery_photos ||= begin
        business.booking_attachments.marketing_approved
          .includes(file_attachment: :blob)
          .recent_first
          .limit(limit)
          .select { |attachment| attachment.file.attached? && attachment.file.image? }
      end
    end

    def professionals(limit: 4)
      return [] unless business.public_booking_show_team_members? && business.public_show_professionals?

      @professionals ||= business.employee_memberships.available_for_booking
        .with_attached_profile_photo
        .includes(:branch, user: { profile_photo_attachment: :blob })
        .order(:sort_order, :name)
        .limit(limit)
        .to_a
    end

    def gap_promos(limit: 3)
      return [] unless business.public_show_gap_promos?

      @gap_promos ||= business.promotions.active.includes(:service, :campaign_link).order(:ends_at).limit(limit).to_a
    end

    def faq_items(for_service: service)
      items = []
      Array(for_service&.faq).each do |item|
        question = item["question"] || item[:question]
        answer = item["answer"] || item[:answer]
        items << { question:, answer: } if question.present? && answer.present?
      end

      items << { question: "¿Cómo reservo un turno?", answer: "Elegí un servicio, seleccioná día y horario, y dejá tus datos de contacto. #{business.name} te confirmará la solicitud." }
      items << { question: "¿Tengo que pagar seña?", answer: deposit_faq_answer(for_service) }
      items << { question: "¿Puedo cambiar o cancelar?", answer: business.cancellation_policy_text }
      items.first(5)
    end

    def booking_path(service: nil, slot: nil)
      selected_service = service || slot&.service || featured_services.first
      return PublicUrls.path(:business, business, **tracking_params, use_custom_domain: @use_custom_domain) if selected_service.blank?

      query = tracking_params
      if slot&.starts_at.present?
        query = query.merge(date: slot.starts_at.to_date)
        query[:employee_membership_id] = slot.employee_membership.id if slot.employee_membership.present?
      end

      PublicUrls.path(:short_service, business, selected_service.slug, **query, use_custom_domain: @use_custom_domain)
    end

    def service_path(service)
      PublicUrls.path(:short_service, business, service.slug, **tracking_params, use_custom_domain: @use_custom_domain)
    end

    def category_path(category)
      PublicUrls.path(:category, business, category.slug, **tracking_params, use_custom_domain: @use_custom_domain)
    end

    def category_url(category)
      PublicUrls.url(:category, business, category.slug, **tracking_params, use_custom_domain: @use_custom_domain)
    end

    def services_path
      PublicUrls.path(:services, business, **tracking_params, use_custom_domain: @use_custom_domain)
    end

    def home_path(**options)
      PublicUrls.path(:business, business, **tracking_params.merge(options), use_custom_domain: @use_custom_domain)
    end

    def waitlist_path
      PublicUrls.path(:waitlist, business, use_custom_domain: @use_custom_domain)
    end

    def whatsapp_url
      business.whatsapp_contact_link.presence || business.contact_whatsapp_link
    end

    def public_url
      PublicLinks::UrlBuilder.business(business)
    end

    def canonical_url
      service.present? ? PublicLinks::UrlBuilder.service(service) : public_url
    end

    def page_title
      service.present? ? "#{service.name} · #{business.name}" : "#{business.name} · Turnos online"
    end

    def page_description
      if service.present?
        service.description
      else
        business.public_intro
      end
    end

    def hero_title
      return service.name if service.present?

      business.public_booking_headline
    end

    def hero_kicker
      if service.present?
        service.category_label
      else
        [ business.industry_category, business.public_city ].compact_blank.join(" · ")
      end
    end

    def hero_description
      service.present? ? service.description : business.public_intro
    end

    def show_prices?
      business.public_show_prices?
    end

    def show_deposits?
      business.public_show_deposit_amounts?
    end

    def show_location?
      business.public_show_location?
    end

    def show_waitlist?
      business.public_show_waitlist? && services.any?
    end

    def show_next_slots?
      business.public_show_next_slots?
    end

    def full_website_mode?
      business.full_website_mode?
    end

    def custom_html
      business.public_custom_html.to_s
    end

    private
      def build_next_available_slots(limit:, for_service:)
        target_services = for_service.present? ? [ for_service ] : featured_services.first(3)
        slots = []

        target_services.each do |candidate_service|
          (Time.zone.today..7.days.from_now.to_date).each do |date|
            slot = Availability::Slots.first_record_for(business:, service: candidate_service, date:)
            next if slot.blank?

            slots << LandingSlot.new(service: candidate_service, starts_at: slot.starts_at, employee_membership: slot.employee_membership)
            break if for_service.blank? || slots.size >= limit
          end
          break if slots.size >= limit
        end

        slots.sort_by(&:starts_at).first(limit)
      rescue StandardError
        []
      end

      def tracking_params
        @tracking_params ||= params.slice(*TRACKING_KEYS).compact_blank.symbolize_keys
      end

      def deposit_faq_answer(for_service)
        return "Este negocio no requiere seña para reservar." unless business.deposits_enabled?
        return "#{for_service.deposit_summary}. Vas a poder subir el comprobante durante la reserva." if for_service&.deposit_required?
        return "Este servicio no requiere seña para reservar." if for_service.present?

        "Algunos servicios pueden requerir seña. Si corresponde, vas a poder subir el comprobante durante la reserva."
      end

  end
end
