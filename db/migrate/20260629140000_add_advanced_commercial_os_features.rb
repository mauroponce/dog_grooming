require "set"

class AddAdvancedCommercialOsFeatures < ActiveRecord::Migration[8.1]
  def change
    change_table :businesses, bulk: true do |t|
      t.boolean :public_directory_enabled, null: false, default: false
      t.string :province
      t.string :neighborhood
    end
    add_index :businesses, [ :public_directory_enabled, :province, :city ], name: "idx_businesses_public_directory"

    change_table :services, bulk: true do |t|
      t.string :slug
      t.text :public_description
      t.text :includes
      t.text :before_care
      t.text :after_care
      t.jsonb :faq, null: false, default: []
      t.boolean :public_visible, null: false, default: true
    end
    reversible do |dir|
      dir.up { backfill_service_slugs! }
    end
    change_column_null :services, :slug, false
    add_index :services, [ :business_id, :slug ], unique: true, name: "idx_services_business_slug"
    add_index :services, [ :business_id, :public_visible, :active ], name: "idx_services_public_visible"

    change_table :booking_attachments, bulk: true do |t|
      t.string :marketing_consent_status, null: false, default: "not_requested"
      t.datetime :marketing_consent_requested_at
      t.datetime :marketing_consent_approved_at
      t.string :marketing_consent_source
    end
    add_index :booking_attachments, [ :business_id, :marketing_consent_status ], name: "idx_booking_attachments_marketing_consent"

    create_table :booking_intents do |t|
      t.references :business, null: false, foreign_key: true
      t.references :customer_profile, foreign_key: true
      t.references :service, foreign_key: true
      t.references :employee_membership, foreign_key: true
      t.references :appointment, foreign_key: true
      t.datetime :selected_starts_at
      t.string :full_name
      t.string :phone_e164
      t.string :status, null: false, default: "started"
      t.datetime :expires_at
      t.datetime :completed_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :booking_intents, [ :business_id, :status, :expires_at ], name: "idx_booking_intents_business_status_expires"
    add_index :booking_intents, [ :business_id, :phone_e164, :service_id, :status ], name: "idx_booking_intents_recovery_lookup"

    create_table :gift_cards do |t|
      t.references :business, null: false, foreign_key: true
      t.references :service, foreign_key: true
      t.references :redeemed_booking, foreign_key: { to_table: :appointments }
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :code, null: false
      t.string :buyer_name
      t.string :buyer_phone_e164
      t.string :recipient_name
      t.string :recipient_phone_e164
      t.integer :amount_cents
      t.string :title, null: false
      t.text :message
      t.string :status, null: false, default: "draft"
      t.datetime :expires_at
      t.datetime :purchased_at
      t.datetime :redeemed_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :gift_cards, [ :business_id, :code ], unique: true, name: "idx_gift_cards_business_code"
    add_index :gift_cards, [ :business_id, :status, :created_at ], name: "idx_gift_cards_business_status_created"

    create_table :service_forms do |t|
      t.references :business, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.boolean :active, null: false, default: false

      t.timestamps
    end
    add_index :service_forms, [ :business_id, :service_id ], unique: true, name: "idx_service_forms_business_service"

    create_table :service_form_questions do |t|
      t.references :business, null: false, foreign_key: true
      t.references :service_form, null: false, foreign_key: true
      t.string :label, null: false
      t.string :question_type, null: false
      t.boolean :required, null: false, default: false
      t.jsonb :options, null: false, default: []
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :service_form_questions, [ :service_form_id, :position ], name: "idx_service_form_questions_position"

    create_table :service_form_responses do |t|
      t.references :business, null: false, foreign_key: true
      t.references :appointment, null: false, foreign_key: true
      t.references :customer_profile, null: false, foreign_key: true
      t.references :service_form, null: false, foreign_key: true
      t.jsonb :answers, null: false, default: {}

      t.timestamps
    end
    add_index :service_form_responses, [ :appointment_id, :service_form_id ], unique: true, name: "idx_service_form_responses_appointment_form"

    create_table :content_templates do |t|
      t.references :business, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.text :body, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :content_templates, [ :business_id, :key ], unique: true, name: "idx_content_templates_business_key"

    create_table :commercial_calendar_events do |t|
      t.string :name, null: false
      t.date :event_date, null: false
      t.string :country, null: false, default: "AR"
      t.string :category, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :commercial_calendar_events, [ :country, :event_date, :active ], name: "idx_commercial_calendar_country_date"
    reversible do |dir|
      dir.up { seed_commercial_calendar_events! }
    end

    create_table :promotions do |t|
      t.references :business, null: false, foreign_key: true
      t.references :service, foreign_key: true
      t.references :campaign_link, foreign_key: true
      t.string :name, null: false
      t.string :promotion_type, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.text :description
      t.string :status, null: false, default: "draft"
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :promotions, [ :business_id, :status, :starts_at ], name: "idx_promotions_business_status_starts"
  end

  private
    def backfill_service_slugs!
      used_by_business = Hash.new { |hash, key| hash[key] = Set.new }
      select_all("SELECT id, business_id, name, slug FROM services ORDER BY business_id, id").each do |row|
        business_id = row.fetch("business_id")
        base = normalize_slug(row["slug"].presence || row["name"].presence || "servicio")
        candidate = base
        counter = 2
        while used_by_business[business_id].include?(candidate)
          suffix = "-#{counter}"
          candidate = "#{base.first(60 - suffix.length).gsub(/-+\z/, "")}#{suffix}"
          counter += 1
        end
        used_by_business[business_id] << candidate
        execute "UPDATE services SET slug = #{quote(candidate)} WHERE id = #{row.fetch("id").to_i}"
      end
    end

    def normalize_slug(value)
      I18n.transliterate(value.to_s)
        .downcase
        .gsub(/[^a-z0-9]+/, "-")
        .gsub(/-+/, "-")
        .gsub(/\A-|-+\z/, "")
        .presence
        .then { |slug| (slug || "servicio").first(60).gsub(/-+\z/, "") }
    end

    def seed_commercial_calendar_events!
      year = Date.current.year
      [
        [ "San Valentín", Date.new(year, 2, 14), "seasonal" ],
        [ "Día de la Mujer", Date.new(year, 3, 8), "seasonal" ],
        [ "Día de la Madre", Date.new(year, 10, 18), "seasonal" ],
        [ "Black Friday", Date.new(year, 11, 27), "retail" ],
        [ "Navidad", Date.new(year, 12, 25), "holiday" ],
        [ "Año Nuevo", Date.new(year + 1, 1, 1), "holiday" ]
      ].each do |name, date, category|
        execute <<~SQL.squish
          INSERT INTO commercial_calendar_events (name, event_date, country, category, active, created_at, updated_at)
          VALUES (#{quote(name)}, #{quote(date)}, 'AR', #{quote(category)}, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end
    end
end
