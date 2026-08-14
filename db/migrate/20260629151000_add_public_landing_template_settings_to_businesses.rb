class AddPublicLandingTemplateSettingsToBusinesses < ActiveRecord::Migration[8.1]
  def change
    change_table :businesses, bulk: true do |t|
      t.string :public_template, null: false, default: "clean_clinic"
      t.string :public_primary_color
      t.string :public_secondary_color
      t.string :public_accent_color
      t.string :public_font_style
      t.boolean :public_landing_enabled, null: false, default: true
      t.boolean :public_show_prices, null: false, default: true
      t.boolean :public_show_deposit_amounts, null: false, default: true
      t.boolean :public_show_professionals, null: false, default: true
      t.boolean :public_show_gallery, null: false, default: true
      t.boolean :public_show_reviews, null: false, default: true
      t.boolean :public_show_location, null: false, default: true
      t.boolean :public_show_waitlist, null: false, default: true
      t.boolean :public_show_next_slots, null: false, default: true
      t.boolean :public_show_gap_promos, null: false, default: true
    end

    add_index :businesses, :public_template
  end
end
