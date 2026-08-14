class ContentTemplate < ApplicationRecord
  DEFAULTS = {
    "instagram_story_booking" => {
      name: "Historia: link de reservas",
      body: "Ya podés reservar tu turno online en {{business_name}}. Elegí tratamiento, día y horario desde acá: {{public_booking_link}}"
    },
    "promote_service" => {
      name: "Promocionar servicio",
      body: "{{service_name}} en {{business_name}}. Reservá tu turno acá: {{service_link}}"
    },
    "gift_card_offer" => {
      name: "Promocionar gift card",
      body: "Regalá un momento de cuidado en {{business_name}}. Pedinos una gift card por WhatsApp."
    },
    "pack_offer" => {
      name: "Vender pack",
      body: "Tenemos packs para que mantengas tu tratamiento con más orden. Consultanos por WhatsApp o reservá acá: {{public_booking_link}}"
    }
  }.freeze

  belongs_to :business, optional: true

  validates :key, :name, :body, presence: true
  validates :key, uniqueness: { scope: :business_id }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:key) }

  def self.ensure_defaults_for!(business)
    DEFAULTS.each do |key, attrs|
      business.content_templates.find_or_create_by!(key:) do |template|
        template.name = attrs.fetch(:name)
        template.body = attrs.fetch(:body)
        template.active = true
      end
    end
  end

  def render_for(business:, service: nil, campaign_link: nil)
    body.gsub(/\{\{([a-z_]+)\}\}/) do
      variable = Regexp.last_match(1)
      {
        "business_name" => business.name,
        "public_booking_link" => business.public_url,
        "service_name" => service&.name.to_s,
        "service_link" => service&.public_service_url.to_s,
        "campaign_link" => campaign_link&.tracked_url.to_s,
      }.fetch(variable, "")
    end
  end
end
