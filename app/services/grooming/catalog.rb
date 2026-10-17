module Grooming
  class Catalog
    SERVICES = [
      [ "Baño y secado", [ 15_000, 20_000, 25_000 ], [ 45, 60, 90 ] ],
      [ "Sólo corte", [ 18_000, 23_000, 28_000 ], [ 30, 45, 60 ] ],
      [ "Baño + corte", [ 25_000, 32_000, 40_000 ], [ 75, 105, 135 ] ]
    ].freeze

    def self.templates
      SERVICES.map do |name, prices, durations|
        { name: name, category: name, price: prices.first, duration_minutes: durations.first,
          description: "#{name} con precio y duración según el peso de la mascota.", deposit_required: true,
          deposit_percentage: 50, deposit_amount_cents: prices.first * 50,
          variants: prices.zip(durations).map { |price, duration| { price_cents: price * 100, duration_minutes: duration } } }
      end
    end

    def self.install!(business)
      business.with_lock do
        bands = business.ensure_default_pet_size_bands!.to_a
        templates.each do |attrs|
          category = ServiceCategory.find_or_create_for!(business: business, name: attrs.fetch(:category))
          variant_attrs = attrs.fetch(:variants)
          service = business.services.find_or_initialize_by(name: attrs.fetch(:name))
          service.assign_attributes(attrs.except(:variants).merge(service_category: category, pricing_mode: "by_pet_size")) if service.new_record?
          service.save!
          bands.zip(variant_attrs).each do |band, variant|
            service.service_variants.find_or_create_by!(pet_size_band: band) { |record| record.assign_attributes(variant) }
          end
        end
      end
    end
  end
end
