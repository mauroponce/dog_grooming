class AddPreferencesToBusinesses < ActiveRecord::Migration[8.1]
  DEFAULT_PREFERENCES = {
    chatbot_enabled: true,
    deposits_enabled: false,
    deposit_percentage: 50
  }.freeze

  def up
    add_column :businesses, :preferences, :jsonb, null: false, default: {}
    add_index :businesses, :preferences, using: :gin

    Business.reset_column_information
    Business.find_each do |business|
      business.update_columns(
        preferences: DEFAULT_PREFERENCES.merge(
          chatbot_enabled: true
        ).as_json,
        updated_at: Time.current
      )
    end
  end

  def down
    remove_index :businesses, :preferences
    remove_column :businesses, :preferences
  end
end
