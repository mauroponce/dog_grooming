class AddPremiumAiFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_chat_conversations do |t|
      t.references :business, null: false, foreign_key: true
      t.string :visitor_token, null: false
      t.string :customer_name
      t.string :customer_phone
      t.string :status, null: false, default: "open"
      t.string :last_intent
      t.text :summary
      t.string :summary_status, null: false, default: "pending"
      t.datetime :summarized_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :ai_chat_conversations, [ :business_id, :visitor_token ], unique: true
    add_index :ai_chat_conversations, [ :business_id, :status, :updated_at ]

    create_table :ai_chat_messages do |t|
      t.references :ai_chat_conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :ai_chat_messages, [ :ai_chat_conversation_id, :created_at ], name: "idx_ai_chat_messages_on_conversation_and_created_at"

    create_table :appointment_reviews do |t|
      t.references :appointment, null: false, foreign_key: true, index: false
      t.references :business, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :comment, null: false
      t.string :status, null: false, default: "pending"
      t.decimal :sentiment_score, precision: 5, scale: 2
      t.string :ai_tags, array: true, null: false, default: []
      t.text :ai_summary
      t.text :ai_recommendation
      t.jsonb :analysis_payload, null: false, default: {}
      t.datetime :analyzed_at
      t.timestamps
    end
    add_index :appointment_reviews, :appointment_id, unique: true
    add_index :appointment_reviews, [ :business_id, :status, :created_at ]

    create_table :ai_context_imports do |t|
      t.references :business, null: false, foreign_key: true
      t.string :source_url
      t.text :raw_text
      t.string :status, null: false, default: "pending"
      t.text :generated_context
      t.text :error_message
      t.datetime :processed_at
      t.timestamps
    end
    add_index :ai_context_imports, [ :business_id, :created_at ]
  end
end
