module ServiceCatalog
  class DefaultCatalog
    CATEGORIES = [
      {
        name: "Baño y secado",
        services: [
          "Baño y secado",
          "Baño y corte",
          "Baño para cachorro",
          "Baño medicado",
          "Baño antipulgas",
          "Secado y cepillado",
          "Hidratación de manto",
          "Servicio completo"
        ]
      },
      {
        name: "Corte y arreglo",
        services: [
          "Corte higiénico",
          "Corte de raza",
          "Corte a tijera",
          "Corte comercial",
          "Corte de verano",
          "Perfilado de patas",
          "Arreglo de cara",
          "Recorte de flequillo",
          "Deslanado intensivo",
          "Cepillado profundo"
        ]
      },
      {
        name: "Higiene y bienestar",
        services: [
          "Higiene completa",
          "Corte de uñas",
          "Limpieza de oídos",
          "Higiene de almohadillas",
          "Limpieza dental básica",
          "Vaciado de glándulas anales",
          "Control de nudos",
          "Peinado y perfume"
        ]
      },
      {
        name: "Cachorros y adaptación",
        services: [
          "Primera visita puppy",
          "Baño suave para cachorro",
          "Adaptación a secador",
          "Adaptación a mesa de grooming",
          "Higiene inicial de cachorro"
        ]
      },
      {
        name: "Mantos especiales",
        services: [
          "Spa e hidratación",
          "Tratamiento anti-nudos",
          "Tratamiento para manto doble",
          "Deslanado de muda",
          "Recuperación de manto",
          "Cuidado de pelo largo"
        ]
      },
      {
        name: "Packs de grooming",
        services: [
          "Pack baño e higiene",
          "Pack baño y corte",
          "Pack mantenimiento mensual",
          "Pack cachorro",
          "Pack manto largo"
        ]
      }
    ].freeze

    def self.seed!
      new.seed!
    end

    def seed!
      keys = CATEGORIES.map { |category| key_for(category.fetch(:name)) }
      ServiceCatalogCategory.where.not(key: keys).update_all(active: false)

      CATEGORIES.each_with_index do |category_data, category_index|
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
          item = category.service_catalog_items.find_or_initialize_by(name: service_name)
          item.assign_attributes(
            service_category: category.name,
            description: "#{service_name} en #{category.name}.",
            duration_minutes: default_duration_for(service_name),
            price_cents: 0,
            deposit_amount_cents: 0,
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
