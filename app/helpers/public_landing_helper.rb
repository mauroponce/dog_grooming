module PublicLandingHelper
  PUBLIC_CUSTOM_SECTION_TAGS = %w[
    a article aside blockquote br div dl dt dd em figcaption figure footer h1 h2 h3 h4 h5 h6 header hr
    img li main nav ol p section small span strong style ul video
  ].freeze
  PUBLIC_CUSTOM_SECTION_ATTRIBUTES = %w[
    alt aria-hidden aria-label autoplay class data-dog-grooming-slot decoding height href id loading loop muted playsinline poster preload role src title width
  ].freeze
  PUBLIC_CUSTOM_CATEGORIES_SLOT = "__DOG_GROOMING_CATEGORIES_SLOT__".freeze
  PUBLIC_CUSTOM_SERVICES_SLOT = "__DOG_GROOMING_SERVICES_SLOT__".freeze
  PUBLIC_CUSTOM_SLOTS = {
    categories: PUBLIC_CUSTOM_CATEGORIES_SLOT,
    services: PUBLIC_CUSTOM_SERVICES_SLOT
  }.freeze
  PUBLIC_FULL_WEBSITE_BASE_CSS = <<~CSS.freeze
    .ht-full-website { min-height: 100vh; overflow: clip; background: #fff; color: #17202a; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }
    .ht-custom-sections { overflow: clip; }
    .ht-section { padding: clamp(3.5rem, 8vw, 7rem) 1.25rem; }
    .ht-section__inner { width: min(100%, 72rem); margin-inline: auto; }
    .ht-section__eyebrow { margin: 0 0 .75rem; font-size: .72rem; font-weight: 700; letter-spacing: .18em; text-transform: uppercase; opacity: .7; }
    .ht-section h2 { margin: 0; font-size: clamp(2rem, 4vw, 3.5rem); line-height: 1.05; }
    .ht-section p { line-height: 1.7; }
    .ht-section img { display: block; max-width: 100%; }
    .ht-about__image { width: 100%; border-radius: 1.5rem; object-fit: cover; }
    @media (min-width: 768px) {
      .ht-about .ht-section__inner { display: grid; grid-template-columns: minmax(0, .9fr) minmax(0, 1.1fr); align-items: center; gap: clamp(2.5rem, 6vw, 6rem); }
    }
    .ht-services, .ht-professionals, .ht-category-page { padding: clamp(3.5rem, 8vw, 7rem) 1.25rem; }
    .ht-services__inner, .ht-professionals__inner, .ht-category-page__inner { width: min(100%, 72rem); margin-inline: auto; }
    .ht-services__eyebrow, .ht-professionals__eyebrow { margin: 0 0 .75rem; font-size: .72rem; font-weight: 700; letter-spacing: .18em; text-transform: uppercase; opacity: .7; }
    .ht-services__heading, .ht-professionals__heading, .ht-category-page h1 { margin: 0; font-size: clamp(2rem, 4vw, 3.5rem); line-height: 1.05; }
    .ht-category-grid, .ht-professional-grid, .ht-service-grid { display: grid; gap: 1.25rem; margin-top: 2.5rem; }
    .ht-category-card, .ht-professional-card, .ht-service-card { overflow: hidden; border: 1px solid currentColor; border-radius: 1rem; color: inherit; text-decoration: none; }
    .ht-category-card__image, .ht-service-card__image { display: block; width: 100%; aspect-ratio: 16 / 9; object-fit: cover; }
    .ht-category-card__image--placeholder { background: #ececec; }
    .ht-category-card__body, .ht-service-card__body, .ht-professional-card { padding: 1.25rem; }
    .ht-category-card h3, .ht-service-card h2, .ht-professional-card h3 { margin: 0; font-size: 1.25rem; }
    .ht-category-card p, .ht-service-card p, .ht-professional-card p { margin: .7rem 0 0; line-height: 1.6; opacity: .75; }
    .ht-category-card__action, .ht-service-card__action { display: inline-block; margin-top: 1.25rem; font-weight: 700; }
    .ht-professional-card__photo { display: block; width: 4rem; height: 4rem; border-radius: 999px; object-fit: cover; }
    .ht-professional-card__initials { display: grid; width: 4rem; height: 4rem; place-items: center; border-radius: 999px; background: #17202a; color: #fff; font-weight: 700; }
    .ht-category-page__back { color: inherit; font-weight: 700; }
    .ht-category-page__description { max-width: 44rem; line-height: 1.7; }
    @media (min-width: 640px) { .ht-category-grid, .ht-professional-grid, .ht-service-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
    @media (min-width: 960px) { .ht-category-grid, .ht-professional-grid, .ht-service-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
  CSS

  def public_full_website_base_styles_tag
    tag.style(PUBLIC_FULL_WEBSITE_BASE_CSS.html_safe, data: { public_full_website_base_css: true })
  end

  def public_custom_sections(landing, html: landing.custom_html, category: nil, slot: :categories)
    safe_html = public_custom_sections_parts(landing, html:, category:, slot:).join
    return if safe_html.blank?

    tag.div(safe_html, class: "ht-custom-sections", data: { public_custom_sections: true })
  end

  def public_custom_sections_parts(landing, html: landing.custom_html, category: nil, slot: :categories)
    return [] unless landing.full_website_mode?
    return [] if html.blank?

    slot_marker = PUBLIC_CUSTOM_SLOTS.fetch(slot)
    safe_html = sanitize_public_custom_html(
      interpolate_public_custom_html(html, landing:, category:).gsub(
        /<div\b[^>]*\bdata-dog-grooming-slot\s*=\s*(?:"#{slot}"|'#{slot}')[^>]*>\s*<\/div>/i,
        slot_marker
      )
    )
    return [] if safe_html.blank?

    safe_html.split(slot_marker, -1)
  end

  def public_custom_html_styles_tag(landing, html: landing.custom_html, category: nil)
    return unless landing.full_website_mode?
    return if html.blank?

    styles = interpolate_public_custom_html(html, landing:, category:).scan(%r{<style\b[^>]*>(.*?)</style\s*>}im).flatten
    return if styles.blank?

    safe_join(styles.map do |css|
      tag.style(css.gsub(%r{</style\b[^>]*>}i, "").html_safe, data: { public_custom_html_css: true })
    end)
  end

  private

  def interpolate_public_custom_html(html, landing:, category:)
    business = landing.business
    instagram_handle = business.instagram_url.to_s.sub(%r{\Ahttps?://(www\.)?instagram\.com/}i, "").delete_prefix("@").delete_suffix("/")
    values = {
      "{{business_name}}" => business.name,
      "{{business_slogan}}" => business.public_booking_headline,
      "{{business_intro}}" => business.public_intro,
      "{{business_phone}}" => business.public_phone,
      "{{business_email}}" => business.public_email.presence || business.owner.email_address,
      "{{business_address}}" => business.public_location,
      "{{business_instagram_url}}" => business.instagram_url,
      "{{business_instagram_handle}}" => instagram_handle.present? ? "@#{instagram_handle}" : "",
      "{{business_whatsapp_url}}" => landing.whatsapp_url,
      "{{business_logo_url}}" => business.logo.attached? ? url_for(business.logo) : "",
      "{{home_url}}" => landing.home_path,
      "{{services_url}}" => landing.home_path(anchor: "servicios"),
      "{{current_year}}" => Time.zone.today.year,
      "{{category_name}}" => category&.name,
      "{{category_name_uppercase}}" => category&.name&.upcase,
      "{{category_description}}" => category&.description,
      "{{category_url}}" => category.present? ? landing.category_path(category) : "",
      "{{category_service_count}}" => category.present? ? landing.services_for_category(category).size : ""
    }

    values.reduce(html.to_s) do |rendered_html, (placeholder, value)|
      rendered_html.gsub(placeholder, ERB::Util.html_escape(value.to_s))
    end
  end

  def sanitize_public_custom_html(html)
    sanitize(
      html,
      tags: PUBLIC_CUSTOM_SECTION_TAGS,
      attributes: PUBLIC_CUSTOM_SECTION_ATTRIBUTES
    )
  end

  public

  def landing_price_label(service, landing)
    landing.show_prices? ? service.display_price : "Consultar"
  end

  def landing_deposit_label(service, landing)
    return "Seña a confirmar" unless landing.show_deposits?

    service.deposit_summary
  end

  def landing_service_meta(service, landing)
    [
      "#{service.duration_minutes} min",
      landing_price_label(service, landing),
      landing_deposit_label(service, landing)
    ].compact_blank
  end

  def landing_slot_label(slot)
    "#{public_date_label(slot.starts_at.to_date)} · #{format_ar_time(slot.starts_at)}"
  end

  def landing_schema_payload(landing)
    business = landing.business
    payload = {
      "@context" => "https://schema.org",
      "@type" => "BeautySalon",
      "name" => business.name,
      "description" => landing.page_description,
      "url" => landing.canonical_url,
      "telephone" => business.public_phone,
      "address" => business.public_location
    }

    if landing.service.present?
      payload["makesOffer"] = {
        "@type" => "Offer",
        "itemOffered" => {
          "@type" => "Service",
          "name" => landing.service.name,
            "description" => landing.service.description
        }
      }
      payload["makesOffer"]["price"] = landing.service.price_cents / 100 if landing.show_prices? && landing.service.price_cents.positive?
      payload["makesOffer"]["priceCurrency"] = "ARS" if landing.show_prices? && landing.service.price_cents.positive?
    else
      payload["makesOffer"] = landing.featured_services.map do |service|
        offer = {
          "@type" => "Offer",
          "itemOffered" => {
            "@type" => "Service",
            "name" => service.name,
            "description" => service.description
          }
        }
        offer["price"] = service.price_cents / 100 if landing.show_prices? && service.price_cents.positive?
        offer["priceCurrency"] = "ARS" if landing.show_prices? && service.price_cents.positive?
        offer
      end
    end

    payload
  end

  def landing_head_tags(landing)
    safe_join([
      tag.meta(name: "description", content: landing.page_description),
      tag.link(rel: "canonical", href: landing.canonical_url),
      tag.meta(property: "og:title", content: landing.page_title),
      tag.meta(property: "og:description", content: landing.page_description),
      tag.meta(property: "og:url", content: landing.canonical_url),
      tag.meta(property: "og:type", content: landing.service.present? ? "article" : "website"),
      tag.script(json_escape(landing_schema_payload(landing).to_json).html_safe, type: "application/ld+json")
    ])
  end
end
