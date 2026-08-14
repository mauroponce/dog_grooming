class AddBusinessServiceCategories < ActiveRecord::Migration[8.1]
  class MigrationBusiness < ActiveRecord::Base
    self.table_name = "businesses"

    has_many :migration_services, class_name: "AddBusinessServiceCategories::MigrationService", foreign_key: :business_id
  end

  class MigrationService < ActiveRecord::Base
    self.table_name = "services"
  end

  class MigrationServiceCatalogCategory < ActiveRecord::Base
    self.table_name = "service_catalog_categories"
  end

  class MigrationServiceCategory < ActiveRecord::Base
    self.table_name = "service_categories"
  end

  def change
    create_table :service_categories do |t|
      t.references :business, null: false, foreign_key: true
      t.references :service_catalog_category, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.boolean :primary_category, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0

      t.timestamps
    end

    add_index :service_categories, [ :business_id, :slug ], unique: true
    add_index :service_categories, [ :business_id, :active, :sort_order ], name: "idx_service_categories_business_active_order"
    add_index :service_categories, :business_id, unique: true, where: "primary_category = true", name: "idx_service_categories_one_primary_per_business"

    add_reference :services, :service_category, foreign_key: true
    add_reference :services, :service_catalog_item, foreign_key: true

    reversible do |dir|
      dir.up { backfill_service_categories! }
    end
  end

  private
    def backfill_service_categories!
      MigrationBusiness.reset_column_information
      MigrationService.reset_column_information
      MigrationServiceCatalogCategory.reset_column_information
      MigrationServiceCategory.reset_column_information

      MigrationBusiness.find_each do |business|
        catalog_category = MigrationServiceCatalogCategory.find_by(id: business.service_catalog_category_id)
        category_names = business.migration_services.where.not(category: [ nil, "" ]).distinct.order(:category).pluck(:category)
        category_names = [ catalog_category.name ] if category_names.blank? && catalog_category.present?

        category_names.each_with_index do |name, index|
          service_category = MigrationServiceCategory.create!(
            business_id: business.id,
            service_catalog_category_id: catalog_category&.name == name ? catalog_category.id : nil,
            name: name,
            slug: unique_slug_for(business.id, name),
            primary_category: primary_category?(name, index, catalog_category),
            active: true,
            sort_order: index
          )

          MigrationService.where(business_id: business.id, category: name).update_all(service_category_id: service_category.id)
        end
      end
    end

    def primary_category?(name, index, catalog_category)
      return true if catalog_category.present? && catalog_category.name == name

      index.zero?
    end

    def unique_slug_for(business_id, name)
      base = slug_for(name)
      slug = base
      suffix = 2

      while MigrationServiceCategory.exists?(business_id: business_id, slug: slug)
        slug = "#{base}-#{suffix}"
        suffix += 1
      end

      slug
    end

    def slug_for(value)
      slug = I18n.transliterate(value.to_s)
        .downcase
        .gsub(/[^a-z0-9]+/, "-")
        .gsub(/\A-|-+\z/, "")

      slug.presence || "categoria"
    end
end
