class Branch < ApplicationRecord
  belongs_to :business, touch: true
  has_many :employee_memberships, dependent: :nullify
  has_many :appointments, dependent: :nullify
  has_many :bookable_resources, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :business_id }
  validates :latitude, numericality: { greater_than_or_equal_to: -55.2, less_than_or_equal_to: -21.7 }, allow_blank: true
  validates :longitude, numericality: { greater_than_or_equal_to: -73.7, less_than_or_equal_to: -53.6 }, allow_blank: true
  normalizes :name, :address, :address_details, :city, :phone, :province, :neighborhood, :postal_code, :country, with: ->(value) { value.to_s.strip.presence }

  scope :active, -> { where(active: true) }

  def label
    [ name, city.presence || address ].compact_blank.join(" · ")
  end

  def address_complete?
    address.present? && city.present?
  end

  def geocoded?
    latitude.present? && longitude.present?
  end

  def public_location
    location_parts(include_address_details: true).join(", ").presence || "Ubicación a confirmar"
  end

  def location_search_address
    location_parts(include_address_details: false).join(", ")
  end

  after_commit :broadcast_public_services_later, on: %i[create update destroy]

  private
    def location_parts(include_address_details:)
      address_part = address_without_location_suffix
      parts = [ address_part ]
      parts << address_details if include_address_details
      deduplicate_location_parts(parts + [ neighborhood, city, province ])
    end

    def address_without_location_suffix
      segments = address.to_s.split(",").map { |part| part.squish.presence }.compact
      suffix_keys = [ neighborhood, city, province, country, "Argentina" ].compact_blank.map { |part| location_part_key(part) }

      while segments.many? && suffix_keys.include?(location_part_key(segments.last))
        segments.pop
      end

      segments.join(", ")
    end

    def deduplicate_location_parts(parts)
      seen_keys = []
      parts.each_with_object([]) do |part, cleaned|
        value = part.to_s.squish.presence
        next if value.blank?

        key = location_part_key(value)
        next if seen_keys.include?(key)

        cleaned << value
        value.split(",").each do |segment|
          segment_key = location_part_key(segment)
          seen_keys << segment_key if segment_key.present?
        end
      end
    end

    def location_part_key(value)
      I18n.transliterate(value.to_s).downcase.squish
    end

    def broadcast_public_services_later
      PublicBooking::BroadcastServicesJob.perform_later(business_id)
    end
end
