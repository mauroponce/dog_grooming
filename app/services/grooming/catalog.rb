module Grooming
  class Catalog
    GROUPS = [
      [ "Baño", [ 15_000, 20_000, 25_000 ], [ 45, 60, 90 ] ],
      [ "Sólo corte", [ 18_000, 23_000, 28_000 ], [ 30, 45, 60 ] ],
      [ "Baño + corte", [ 25_000, 32_000, 40_000 ], [ 75, 105, 135 ] ]
    ].freeze

    def self.templates
      GROUPS.flat_map do |category, prices, durations|
        %w[Chico Mediano Grande].each_with_index.map do |size, index|
          { name: "#{category} #{size.downcase}", category: category, price: prices[index], duration_minutes: durations[index],
            description: "#{category} para mascotas de tamaño #{size.downcase}.", deposit_required: true,
            deposit_percentage: 50, deposit_amount_cents: prices[index] * 50 }
        end
      end
    end

    def self.install!(business)
      business.with_lock do
        templates.each do |attrs|
          category = ServiceCategory.find_or_create_for!(business: business, name: attrs.fetch(:category))
          next if business.services.exists?(name: attrs.fetch(:name))

          business.services.create!(attrs.merge(service_category: category))
        end
      end
    end
  end
end
