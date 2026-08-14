class AddPublicProfileFields < ActiveRecord::Migration[8.1]
  def change
    change_table :businesses, bulk: true do |t|
      t.string :address
      t.string :city
      t.text :public_description
    end

    change_table :services, bulk: true do |t|
      t.string :category, null: false, default: "General"
      t.text :description
    end

    add_index :services, [ :business_id, :category ]
  end
end
