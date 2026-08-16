class RemovePetSize < ActiveRecord::Migration[8.1]
  def change
    remove_column :pets, :size, :string
  end
end
