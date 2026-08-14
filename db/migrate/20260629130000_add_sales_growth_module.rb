class AddSalesGrowthModule < ActiveRecord::Migration[8.1]
  def change
    change_table :businesses, bulk: true do |t|
      t.boolean :email_daily_sales_digest, null: false, default: true
      t.boolean :email_weekly_sales_digest, null: false, default: true
      t.boolean :email_campaign_summary, null: false, default: true
      t.boolean :reviews_enabled, null: false, default: false
      t.boolean :referrals_enabled, null: false, default: false
      t.string :google_review_url
      t.text :review_request_text
      t.string :referral_reward_description
    end

    create_table :sales_opportunities do |t|
      t.references :business, null: false, foreign_key: true
      t.references :customer_profile, foreign_key: true
      t.references :service, foreign_key: true
      t.references :appointment, foreign_key: true
      t.references :employee_membership, foreign_key: true
      t.string :opportunity_type, null: false
      t.string :title, null: false
      t.text :body
      t.integer :score, null: false, default: 0
      t.string :status, null: false, default: "open"
      t.datetime :due_at
      t.datetime :contacted_at
      t.datetime :dismissed_at
      t.datetime :converted_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :sales_opportunities, [ :business_id, :status, :score ], name: "idx_sales_opportunities_business_status_score"
    add_index :sales_opportunities, [ :business_id, :opportunity_type, :created_at ], name: "idx_sales_opportunities_business_type_created"
    add_index :sales_opportunities, [ :business_id, :customer_profile_id, :service_id, :opportunity_type, :status ], name: "idx_sales_opportunities_dedupe_lookup"

    create_table :campaign_links do |t|
      t.references :business, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :service, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :source, null: false
      t.string :medium
      t.string :campaign
      t.string :destination_type, null: false, default: "public_home"
      t.boolean :active, null: false, default: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :campaign_links, :slug, unique: true
    add_index :campaign_links, [ :business_id, :source, :active ], name: "idx_campaign_links_business_source"

    create_table :campaign_visits do |t|
      t.references :business, null: false, foreign_key: true
      t.references :campaign_link, foreign_key: true
      t.string :session_id
      t.string :visitor_token
      t.string :ip_hash
      t.string :user_agent
      t.string :referer
      t.datetime :visited_at, null: false

      t.timestamps
    end
    add_index :campaign_visits, [ :business_id, :visited_at ], name: "idx_campaign_visits_business_visited"
    add_index :campaign_visits, [ :campaign_link_id, :visited_at ], name: "idx_campaign_visits_link_visited"

    create_table :booking_attributions do |t|
      t.references :business, null: false, foreign_key: true
      t.references :appointment, null: false, foreign_key: true, index: { unique: true }
      t.references :campaign_link, foreign_key: true
      t.string :source
      t.string :medium
      t.string :campaign
      t.string :landing_url
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :booking_attributions, [ :business_id, :campaign_link_id ], name: "idx_booking_attributions_business_link"

    create_table :sales_campaigns do |t|
      t.references :business, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :service, foreign_key: true
      t.references :campaign_link, foreign_key: true
      t.string :name, null: false
      t.string :objective, null: false
      t.string :status, null: false, default: "draft"
      t.text :message_template, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :sales_campaigns, [ :business_id, :status, :created_at ], name: "idx_sales_campaigns_business_status_created"

    create_table :sales_campaign_recipients do |t|
      t.references :business, null: false, foreign_key: true
      t.references :sales_campaign, null: false, foreign_key: true
      t.references :customer_profile, null: false, foreign_key: true
      t.references :converted_booking, foreign_key: { to_table: :appointments }
      t.string :phone_e164, null: false
      t.string :status, null: false, default: "pending"
      t.text :rendered_message
      t.datetime :last_opened_at
      t.datetime :contacted_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :sales_campaign_recipients, [ :sales_campaign_id, :customer_profile_id ], unique: true, name: "idx_sales_campaign_recipients_unique_customer"
    add_index :sales_campaign_recipients, [ :business_id, :status ], name: "idx_sales_campaign_recipients_business_status"

    create_table :service_packs do |t|
      t.references :business, null: false, foreign_key: true
      t.references :service, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :sessions_count, null: false
      t.integer :price_cents
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :service_packs, [ :business_id, :active ], name: "idx_service_packs_business_active"

    create_table :customer_packs do |t|
      t.references :business, null: false, foreign_key: true
      t.references :customer_profile, null: false, foreign_key: true
      t.references :service_pack, null: false, foreign_key: true
      t.datetime :purchased_at, null: false
      t.datetime :expires_at
      t.string :status, null: false, default: "active"
      t.integer :total_sessions, null: false
      t.integer :used_sessions, null: false, default: 0
      t.integer :remaining_sessions, null: false
      t.text :notes

      t.timestamps
    end
    add_index :customer_packs, [ :business_id, :status, :remaining_sessions ], name: "idx_customer_packs_business_status_remaining"
    add_index :customer_packs, [ :customer_profile_id, :status ], name: "idx_customer_packs_customer_status"

    create_table :pack_sessions do |t|
      t.references :business, null: false, foreign_key: true
      t.references :customer_pack, null: false, foreign_key: true
      t.references :appointment, foreign_key: true, index: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :used_at, null: false
      t.text :notes

      t.timestamps
    end
    add_index :pack_sessions, [ :customer_pack_id, :appointment_id ], unique: true, name: "idx_pack_sessions_unique_appointment"

    create_table :review_requests do |t|
      t.references :business, null: false, foreign_key: true
      t.references :customer_profile, null: false, foreign_key: true
      t.references :appointment, null: false, foreign_key: true, index: false
      t.references :requested_by, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.string :channel, null: false, default: "whatsapp_manual"
      t.datetime :requested_at
      t.datetime :opened_whatsapp_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :review_requests, [ :business_id, :customer_profile_id, :created_at ], name: "idx_review_requests_business_customer_created"
    add_index :review_requests, [ :appointment_id, :channel ], unique: true, name: "idx_review_requests_unique_channel"

    create_table :referrals do |t|
      t.references :business, null: false, foreign_key: true
      t.references :referrer_customer, null: false, foreign_key: { to_table: :customer_profiles }
      t.references :referred_customer, foreign_key: { to_table: :customer_profiles }
      t.string :referred_name
      t.string :referred_phone_e164
      t.string :reward_description
      t.string :status, null: false, default: "pending"
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :referrals, [ :business_id, :status, :created_at ], name: "idx_referrals_business_status_created"
    add_index :referrals, [ :business_id, :referred_phone_e164 ], name: "idx_referrals_business_phone"
  end
end
