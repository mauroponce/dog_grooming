class CreateExtras < ActiveRecord::Migration[8.1]
  def change
    create_table :extras do |t|
      t.references :business, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :price_cents, null: false, default: 0
      t.boolean :public_visible, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :appointment_extras do |t|
      t.references :appointment, null: false, foreign_key: true
      t.references :extra, null: false, foreign_key: true
      t.integer :price_cents, null: false, default: 0
      t.timestamps
    end
  end
end
