class SetDogGroomingDefaults < ActiveRecord::Migration[8.1]
  def change
    change_column_default :businesses, :industry, from: "aesthetics", to: "dog_grooming"
    change_column_default :service_catalog_categories, :business_industry, from: "aesthetics", to: "dog_grooming"
  end
end
