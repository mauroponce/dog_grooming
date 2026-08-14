class RemoveBusinessPlan < ActiveRecord::Migration[8.0]
  def up
    remove_column :businesses, :plan, :string if column_exists?(:businesses, :plan)
  end

  def down
    add_column :businesses, :plan, :string, null: false, default: "launch" unless column_exists?(:businesses, :plan)
  end
end
