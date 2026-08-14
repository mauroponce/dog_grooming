class ChangeBusinessKindDefaultToBusiness < ActiveRecord::Migration[8.1]
  def up
    change_column_default :businesses, :business_kind, from: "independent_professional", to: "business"
    execute <<~SQL.squish
      UPDATE businesses
      SET business_kind = 'business'
      WHERE business_kind = 'independent_professional'
    SQL
  end

  def down
    change_column_default :businesses, :business_kind, from: "business", to: "independent_professional"
  end
end
