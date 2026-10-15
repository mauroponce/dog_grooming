class AddGroomingProfileToPets < ActiveRecord::Migration[8.1]
  def change
    add_column :pets, :coat_type, :string
    add_column :pets, :coat_details, :string
    add_column :pets, :behavioral_alerts, :jsonb, default: [], null: false
    add_column :pets, :grooming_reference_note, :text
  end
end
