class CreateTutorials < ActiveRecord::Migration[8.1]
  def change
    create_table :tutorials do |t|
      t.string :title, null: false
      t.text :video_url, null: false

      t.timestamps
    end

    add_index :tutorials, :created_at
  end
end
