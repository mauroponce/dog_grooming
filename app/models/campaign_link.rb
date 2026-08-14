class CampaignLink < ApplicationRecord
  DESTINATION_TYPES = %w[public_home service_page booking_flow campaign_landing].freeze

  belongs_to :business
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :service, optional: true
  has_many :campaign_visits, dependent: :destroy
  has_many :booking_attributions, dependent: :nullify
  has_many :sales_campaigns, dependent: :nullify

  before_validation :ensure_slug

  validates :name, :slug, :source, :destination_type, presence: true
  validates :destination_type, inclusion: { in: DESTINATION_TYPES }
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9][a-z0-9-]{2,80}\z/ }
  validate :service_belongs_to_business

  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }

  def tracked_url
    Rails.application.routes.url_helpers.campaign_link_url(slug: slug, host: app_host, protocol: app_protocol)
  end

  def destination_url
    query = { src: source, medium: medium.presence, campaign: campaign.presence, clid: slug }.compact
    case destination_type
    when "booking_flow"
      if service&.slug.present?
        PublicUrls.url(:short_service, business, service.slug, **query)
      else
        PublicUrls.url(:booking, business, **query)
      end
    when "service_page", "campaign_landing"
      if service&.slug.present?
        PublicUrls.url(:short_service, business, service.slug, **query)
      else
        PublicUrls.url(:services, business, **query)
      end
    else
      PublicUrls.url(:business, business, **query)
    end
  end

  alias_method :destination_path, :destination_url

  def conversion_count
    booking_attributions.count
  end

  def visit_count
    campaign_visits.count
  end

  def conversion_rate
    return 0 if visit_count.zero?

    ((conversion_count / visit_count.to_f) * 100).round
  end

  private
    def ensure_slug
      self.slug = Slugs::GenerateUnique.call([ business&.slug, name ].compact.join("-"), scope: CampaignLink) if slug.blank? && name.present?
    end

    def service_belongs_to_business
      return if service.blank? || business.blank? || service.business_id == business_id

      errors.add(:service, "no pertenece al negocio")
    end

    def app_host
      business.custom_domain_active? ? business.custom_domain : AppUrl.host
    end

    def app_protocol
      AppUrl.protocol
    end
end
