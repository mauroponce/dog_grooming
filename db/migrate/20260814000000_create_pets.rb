class CreatePets < ActiveRecord::Migration[8.0]
  def change
    create_table :pets do |t|
      t.references :business, null: false, foreign_key: true
      t.references :customer_profile, null: false, foreign_key: true
      t.string :name, null: false
      t.string :breed
      t.string :size
      t.string :sex
      t.date :birth_date
      t.text :notes
      t.timestamps

      t.index [ :business_id, :customer_profile_id ]
      t.index [ :customer_profile_id, :name ]
    end

    add_reference :appointments, :pet, foreign_key: { on_delete: :nullify }
  end
end
