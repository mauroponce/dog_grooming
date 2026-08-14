class CreateAiApiUsageEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_api_usage_events do |t|
      t.references :business, foreign_key: true
      t.string :provider, null: false, default: "gemini"
      t.string :feature, null: false, default: "unknown"
      t.string :model
      t.datetime :request_started_at, null: false
      t.datetime :request_finished_at
      t.string :status, null: false, default: "success"
      t.string :error_class
      t.text :error_message
      t.integer :prompt_tokens, null: false, default: 0
      t.integer :completion_tokens, null: false, default: 0
      t.integer :total_tokens, null: false, default: 0
      t.decimal :estimated_cost_usd, precision: 12, scale: 6, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :ai_api_usage_events, [ :provider, :request_started_at ]
    add_index :ai_api_usage_events, [ :business_id, :request_started_at ]
    add_index :ai_api_usage_events, [ :feature, :request_started_at ]
    add_index :ai_api_usage_events, :status
  end
end
