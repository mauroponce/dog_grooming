class AddKindAndIndustryToBusinesses < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :business_kind, :string, null: false, default: "independent_professional"
    add_column :businesses, :industry, :string, null: false, default: "aesthetics"
    add_index :businesses, :industry
  end
end
