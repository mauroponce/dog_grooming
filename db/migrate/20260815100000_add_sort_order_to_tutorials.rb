class AddSortOrderToTutorials < ActiveRecord::Migration[8.1]
  class MigrationTutorial < ActiveRecord::Base
    self.table_name = "tutorials"
  end

  def up
    add_column :tutorials, :sort_order, :integer, null: false, default: 0
    add_index :tutorials, :sort_order

    MigrationTutorial.reset_column_information
    MigrationTutorial.order(created_at: :desc, id: :desc).pluck(:id).each_with_index do |id, index|
      MigrationTutorial.where(id: id).update_all(sort_order: index)
    end
  end

  def down
    remove_index :tutorials, :sort_order
    remove_column :tutorials, :sort_order
  end
end
