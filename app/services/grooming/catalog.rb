module Grooming
  class Catalog
    SIZES = [
      { name: "Chico", description: "Para mascotas de hasta 10 kg." },
      { name: "Mediano", description: "Para mascotas de hasta 20 kg." },
      { name: "Grande", description: "Para mascotas de más de 20 kg." }
    ].freeze

    SERVICES = [
      [ "Baño y secado", [ 15_000, 20_000, 25_000 ], [ 45, 60, 90 ] ],
      [ "Sólo corte", [ 18_000, 23_000, 28_000 ], [ 30, 45, 60 ] ],
      [ "Baño + corte", [ 25_000, 32_000, 40_000 ], [ 75, 105, 135 ] ]
    ].freeze

    def self.templates
      SERVICES.flat_map do |category, prices, durations|
        SIZES.zip(prices, durations).map do |size, price, duration|
          {
            name: "#{category} (#{size.fetch(:name)})",
            category: category,
            price: price,
            duration_minutes: duration,
            description: size.fetch(:description),
            deposit_required: true,
            deposit_amount_cents: price * 50
          }
        end
      end
    end

    def self.install!(business)
      business.with_lock do
        templates.each do |attrs|
          category = ServiceCategory.find_or_create_for!(business: business, name: attrs.fetch(:category))
          service = business.services.find_or_initialize_by(name: attrs.fetch(:name))
          service.assign_attributes(attrs.merge(service_category: category)) if service.new_record?
          service.save!
        end
      end
    end
  end
end
