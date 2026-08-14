class RemoveReviewsAndBusinessPublicDescription < ActiveRecord::Migration[8.0]
  def change
    drop_table :appointment_reviews do |t|
      t.references :appointment, null: false, foreign_key: true
      t.references :business, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :comment, null: false
      t.string :status, null: false, default: "pending"
      t.decimal :sentiment_score, precision: 5, scale: 4
      t.jsonb :ai_tags, null: false, default: []
      t.text :ai_summary
      t.text :ai_recommendation
      t.jsonb :analysis_payload, null: false, default: {}
      t.datetime :analyzed_at
      t.timestamps

      t.index :appointment_id, unique: true
      t.index [ :business_id, :status, :created_at ]
    end

    drop_table :review_requests do |t|
      t.references :business, null: false, foreign_key: true
      t.references :customer_profile, null: false, foreign_key: true
      t.references :appointment, null: false, foreign_key: true
      t.references :requested_by, foreign_key: { to_table: :users }
      t.string :channel, null: false, default: "whatsapp_manual"
      t.string :status, null: false, default: "pending"
      t.datetime :opened_whatsapp_at
      t.datetime :requested_at
      t.datetime :dismissed_at
      t.timestamps

      t.index [ :appointment_id, :channel ], unique: true, name: "idx_review_requests_unique_channel"
      t.index [ :business_id, :customer_profile_id, :created_at ], name: "idx_review_requests_business_customer_created"
    end

    remove_column :businesses, :google_review_url, :string
    remove_column :businesses, :public_description, :text
    remove_column :businesses, :public_show_reviews, :boolean, null: false, default: true
    remove_column :businesses, :review_request_text, :text
    remove_column :businesses, :reviews_enabled, :boolean, null: false, default: false
  end
end
