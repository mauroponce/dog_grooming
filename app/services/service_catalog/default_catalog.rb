module ServiceCatalog
  class DefaultCatalog
    CATEGORIES = Grooming::Catalog::GROUPS.map do |name, _prices, _durations|
      { name: name, services: Grooming::Catalog.templates.select { |item| item[:category] == name }.map { |item| item[:name] } }
    end.freeze

    def self.seed!
      new.seed!
    end

    def seed!
      categories = CATEGORIES
      keys = categories.map { |category| key_for(category.fetch(:name)) }
      ServiceCatalogCategory.where.not(key: keys).update_all(active: false)

      categories.each_with_index do |category_data, category_index|
        seed_category!(category_data, category_index)
      end
    end

    private
      def seed_category!(category_data, category_index)
        category = ServiceCatalogCategory.find_or_initialize_by(key: key_for(category_data.fetch(:name)))
        category.assign_attributes(
          name: category_data.fetch(:name),
          description: "Servicios de #{category_data.fetch(:name).downcase}.",
          business_industry: "dog_grooming",
          active: true,
          sort_order: category_index,
          metadata: category.metadata.to_h.merge("source" => "default_catalog")
        )
        category.save!

        services = category_data.fetch(:services)
        category.service_catalog_items.where.not(name: services).update_all(active: false)

        services.each_with_index do |service_name, service_index|
          defaults = Grooming::Catalog.templates.find { |entry| entry[:name] == service_name }
          item = category.service_catalog_items.find_or_initialize_by(name: service_name)
          item.assign_attributes(
            service_category: category.name,
            description: "#{service_name} en #{category.name}.",
            duration_minutes: defaults.fetch(:duration_minutes),
            price_cents: defaults.fetch(:price) * 100,
            deposit_amount_cents: defaults.fetch(:deposit_amount_cents),
            active: true,
            sort_order: service_index,
            metadata: item.metadata.to_h.merge("source" => "default_catalog")
          )
          item.save!
        end
      end

      def key_for(name)
        I18n.transliterate(name.to_s)
          .downcase
          .gsub(/[^a-z0-9]+/, "_")
          .gsub(/\A_|_+\z/, "")
      end

      def default_duration_for(name)
        normalized = I18n.transliterate(name.to_s).downcase
        return 30 if normalized.match?(/unas|oidos|dental|almohadillas|higienico|glandulas|perfume/)
        return 120 if normalized.match?(/bano y corte|corte de raza|deslanado|servicio completo|manto doble|manto largo/)
        return 90 if normalized.match?(/corte a tijera|anti-nudos|recuperacion de manto/)

        60
      end
  end
end
