# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_19_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointment_addons", force: :cascade do |t|
    t.bigint "appointment_id", null: false
    t.datetime "created_at", null: false
    t.integer "price_cents", default: 0, null: false
    t.bigint "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_appointment_addons_on_appointment_id"
    t.index ["service_id"], name: "index_appointment_addons_on_service_id"
  end

  create_table "appointment_extras", force: :cascade do |t|
    t.bigint "appointment_id", null: false
    t.datetime "created_at", null: false
    t.bigint "extra_id", null: false
    t.integer "price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_appointment_extras_on_appointment_id"
    t.index ["extra_id"], name: "index_appointment_extras_on_extra_id"
  end

  create_table "appointment_payments", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.bigint "appointment_id", null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "ARS", null: false
    t.string "external_reference", null: false
    t.datetime "failed_at"
    t.text "init_point"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "paid_at"
    t.string "preference_id"
    t.string "provider", default: "mercado_pago", null: false
    t.string "provider_merchant_order_id"
    t.string "provider_payment_id"
    t.jsonb "raw_payload", default: {}, null: false
    t.text "sandbox_init_point"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_appointment_payments_on_appointment_id"
    t.index ["business_id", "status"], name: "index_appointment_payments_on_business_id_and_status"
    t.index ["business_id"], name: "index_appointment_payments_on_business_id"
    t.index ["external_reference"], name: "index_appointment_payments_on_external_reference", unique: true
    t.index ["preference_id"], name: "index_appointment_payments_on_preference_id"
    t.index ["provider_payment_id"], name: "index_appointment_payments_on_provider_payment_id"
  end

  create_table "appointments", force: :cascade do |t|
    t.integer "base_price_cents", default: 0, null: false
    t.bigint "bookable_resource_id"
    t.bigint "branch_id"
    t.bigint "business_id", null: false
    t.datetime "canceled_at"
    t.string "canceled_by"
    t.bigint "canceled_by_user_id"
    t.boolean "canceled_late", default: false, null: false
    t.text "cancellation_reason"
    t.datetime "completed_at"
    t.bigint "completed_by_id"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "customer_email"
    t.string "customer_name", null: false
    t.text "customer_notes"
    t.string "customer_phone"
    t.bigint "customer_profile_id"
    t.integer "deposit_amount_cents", default: 0, null: false
    t.string "deposit_payment_method"
    t.jsonb "deposit_receipt_analysis", default: {}, null: false
    t.datetime "deposit_receipt_analyzed_at"
    t.text "deposit_rejection_reason"
    t.string "deposit_review_token", null: false
    t.datetime "deposit_reviewed_at"
    t.bigint "deposit_reviewed_by_id"
    t.string "deposit_status", default: "not_required", null: false
    t.datetime "deposit_submitted_at"
    t.decimal "discount_percentage", precision: 5, scale: 2, default: "0.0", null: false
    t.bigint "employee_membership_id"
    t.datetime "ends_at", null: false
    t.integer "final_price_cents", default: 0, null: false
    t.text "internal_notes"
    t.datetime "no_show_at"
    t.text "notes"
    t.string "payment_charge_mode", default: "none", null: false
    t.string "payment_collection_method", default: "none", null: false
    t.datetime "payment_expires_at"
    t.bigint "pet_id"
    t.datetime "remaining_balance_paid_at"
    t.bigint "remaining_balance_paid_by_id"
    t.integer "remaining_balance_paid_cents", default: 0, null: false
    t.string "remaining_balance_payment_method"
    t.datetime "reminder_sent_at"
    t.bigint "service_id", null: false
    t.string "short_uuid", null: false
    t.integer "source", default: 0, null: false
    t.datetime "starts_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["bookable_resource_id"], name: "index_appointments_on_bookable_resource_id"
    t.index ["branch_id"], name: "index_appointments_on_branch_id"
    t.index ["business_id", "deposit_status", "starts_at"], name: "idx_appointments_business_deposit_status_starts_at"
    t.index ["business_id", "payment_collection_method", "starts_at"], name: "idx_appointments_payment_collection"
    t.index ["business_id", "starts_at"], name: "idx_active_unassigned_appointments", where: "((status <> ALL (ARRAY[2, 8, 9, 10, 11])) AND (employee_membership_id IS NULL))"
    t.index ["business_id", "starts_at"], name: "index_appointments_on_business_id_and_starts_at"
    t.index ["business_id", "status", "customer_profile_id"], name: "idx_appointments_business_status_customer"
    t.index ["business_id", "status", "starts_at"], name: "idx_appointments_business_status_starts_at"
    t.index ["business_id", "status"], name: "index_appointments_on_business_id_and_status"
    t.index ["business_id"], name: "index_appointments_on_business_id"
    t.index ["canceled_by_user_id"], name: "index_appointments_on_canceled_by_user_id"
    t.index ["completed_by_id"], name: "index_appointments_on_completed_by_id"
    t.index ["customer_profile_id"], name: "index_appointments_on_customer_profile_id"
    t.index ["deposit_receipt_analysis"], name: "index_appointments_on_deposit_receipt_analysis", using: :gin
    t.index ["deposit_review_token"], name: "index_appointments_on_deposit_review_token", unique: true
    t.index ["deposit_reviewed_by_id"], name: "index_appointments_on_deposit_reviewed_by_id"
    t.index ["employee_membership_id", "starts_at"], name: "idx_active_employee_appointments", unique: true, where: "((status <> ALL (ARRAY[2, 8, 9, 10, 11])) AND (employee_membership_id IS NOT NULL))"
    t.index ["employee_membership_id"], name: "index_appointments_on_employee_membership_id"
    t.index ["pet_id"], name: "index_appointments_on_pet_id"
    t.index ["remaining_balance_paid_by_id"], name: "index_appointments_on_remaining_balance_paid_by_id"
    t.index ["service_id"], name: "index_appointments_on_service_id"
    t.index ["short_uuid"], name: "index_appointments_on_short_uuid", unique: true
  end

  create_table "availability_blocks", force: :cascade do |t|
    t.string "block_type", default: "center_block", null: false
    t.bigint "bookable_resource_id"
    t.bigint "business_id", null: false
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "description"
    t.bigint "employee_membership_id"
    t.datetime "ends_at", null: false
    t.boolean "online_booking_allowed", default: false, null: false
    t.string "reason"
    t.string "recurrence", default: "none", null: false
    t.date "recurrence_ends_on"
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bookable_resource_id", "starts_at", "ends_at"], name: "idx_availability_blocks_resource_range"
    t.index ["bookable_resource_id"], name: "index_availability_blocks_on_bookable_resource_id"
    t.index ["business_id", "block_type", "cancelled_at"], name: "idx_availability_blocks_type"
    t.index ["business_id", "recurrence", "recurrence_ends_on"], name: "idx_availability_blocks_recurrence"
    t.index ["business_id", "starts_at", "ends_at"], name: "idx_availability_blocks_business_range"
    t.index ["business_id"], name: "index_availability_blocks_on_business_id"
    t.index ["created_by_id"], name: "index_availability_blocks_on_created_by_id"
    t.index ["employee_membership_id", "starts_at", "ends_at"], name: "idx_availability_blocks_employee_range"
    t.index ["employee_membership_id"], name: "index_availability_blocks_on_employee_membership_id"
  end

  create_table "availability_rules", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.time "break_end_time"
    t.time "break_start_time"
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.time "end_time"
    t.time "start_time"
    t.datetime "updated_at", null: false
    t.integer "weekday", null: false
    t.index ["business_id", "weekday"], name: "index_availability_rules_on_business_id_and_weekday", unique: true
    t.index ["business_id"], name: "index_availability_rules_on_business_id"
  end

  create_table "billing_mercado_pago_connections", force: :cascade do |t|
    t.text "access_token_ciphertext"
    t.datetime "connected_at"
    t.datetime "created_at", null: false
    t.datetime "disconnected_at"
    t.datetime "expires_at"
    t.string "mercado_pago_email"
    t.string "mercado_pago_nickname"
    t.string "mercado_pago_user_id"
    t.jsonb "metadata", default: {}, null: false
    t.text "refresh_token_ciphertext"
    t.string "singleton_key", null: false
    t.datetime "updated_at", null: false
    t.index ["mercado_pago_user_id"], name: "index_billing_mercado_pago_connections_on_mercado_pago_user_id"
    t.index ["singleton_key"], name: "index_billing_mercado_pago_connections_on_singleton_key", unique: true
  end

  create_table "billing_reminders", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.string "channel", default: "email", null: false
    t.datetime "created_at", null: false
    t.string "recipient", null: false
    t.string "reminder_type", null: false
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.bigint "subscription_invoice_id", null: false
    t.datetime "updated_at", null: false
    t.date "event_on", null: false
    t.datetime "enqueued_at"
    t.string "active_job_id"
    t.index ["active_job_id"], name: "index_billing_reminders_on_active_job_id"
    t.index ["business_id", "sent_at"], name: "index_billing_reminders_on_business_id_and_sent_at"
    t.index ["business_id"], name: "index_billing_reminders_on_business_id"
    t.index ["subscription_invoice_id", "reminder_type", "channel", "recipient", "event_on"], name: "idx_billing_reminders_event_uniqueness", unique: true
    t.index ["subscription_invoice_id"], name: "index_billing_reminders_on_subscription_invoice_id"
  end

  create_table "billing_transfer_accounts", force: :cascade do |t|
    t.string "account_holder"
    t.string "cbu"
    t.datetime "created_at", null: false
    t.string "singleton_key", default: "primary", null: false
    t.string "tax_id"
    t.string "transfer_alias"
    t.datetime "updated_at", null: false
    t.index ["singleton_key"], name: "index_billing_transfer_accounts_on_singleton_key", unique: true
  end

  create_table "bookable_resources", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "archived_at"
    t.bigint "branch_id"
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "quantity", default: 1, null: false
    t.string "resource_type", default: "space", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_bookable_resources_on_branch_id"
    t.index ["business_id", "archived_at"], name: "idx_bookable_resources_business_archived"
    t.index ["business_id", "name"], name: "index_bookable_resources_on_business_id_and_name", unique: true
    t.index ["business_id", "status", "resource_type"], name: "idx_bookable_resources_business_status_type"
    t.index ["business_id"], name: "index_bookable_resources_on_business_id"
  end

  create_table "booking_attachments", force: :cascade do |t|
    t.bigint "appointment_id", null: false
    t.string "attachment_type", null: false
    t.bigint "business_id", null: false
    t.string "caption"
    t.datetime "created_at", null: false
    t.bigint "customer_profile_id", null: false
    t.datetime "marketing_consent_approved_at"
    t.datetime "marketing_consent_requested_at"
    t.string "marketing_consent_source"
    t.string "marketing_consent_status", default: "not_requested", null: false
    t.datetime "updated_at", null: false
    t.bigint "uploaded_by_id", null: false
    t.string "visibility", default: "internal", null: false
    t.index ["appointment_id", "attachment_type"], name: "idx_booking_attachments_appointment_type"
    t.index ["appointment_id"], name: "index_booking_attachments_on_appointment_id"
    t.index ["business_id", "customer_profile_id", "created_at"], name: "idx_booking_attachments_business_customer_created"
    t.index ["business_id", "marketing_consent_status"], name: "idx_booking_attachments_marketing_consent"
    t.index ["business_id", "visibility"], name: "idx_booking_attachments_business_visibility"
    t.index ["business_id"], name: "index_booking_attachments_on_business_id"
    t.index ["customer_profile_id"], name: "index_booking_attachments_on_customer_profile_id"
    t.index ["uploaded_by_id"], name: "index_booking_attachments_on_uploaded_by_id"
  end

  create_table "booking_attributions", force: :cascade do |t|
    t.bigint "appointment_id", null: false
    t.bigint "business_id", null: false
    t.string "campaign"
    t.bigint "campaign_link_id"
    t.datetime "created_at", null: false
    t.string "landing_url"
    t.string "medium"
    t.jsonb "metadata", default: {}, null: false
    t.string "source"
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_booking_attributions_on_appointment_id", unique: true
    t.index ["business_id", "campaign_link_id"], name: "idx_booking_attributions_business_link"
    t.index ["business_id"], name: "index_booking_attributions_on_business_id"
    t.index ["campaign_link_id"], name: "index_booking_attributions_on_campaign_link_id"
  end

  create_table "booking_intents", force: :cascade do |t|
    t.bigint "appointment_id"
    t.bigint "business_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "customer_profile_id"
    t.bigint "employee_membership_id"
    t.datetime "expires_at"
    t.string "full_name"
    t.jsonb "metadata", default: {}, null: false
    t.string "phone_e164"
    t.datetime "selected_starts_at"
    t.bigint "service_id"
    t.string "status", default: "started", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_booking_intents_on_appointment_id"
    t.index ["business_id", "phone_e164", "service_id", "status"], name: "idx_booking_intents_recovery_lookup"
    t.index ["business_id", "status", "expires_at"], name: "idx_booking_intents_business_status_expires"
    t.index ["business_id"], name: "index_booking_intents_on_business_id"
    t.index ["customer_profile_id"], name: "index_booking_intents_on_customer_profile_id"
    t.index ["employee_membership_id"], name: "index_booking_intents_on_employee_membership_id"
    t.index ["service_id"], name: "index_booking_intents_on_service_id"
  end

  create_table "booking_notes", force: :cascade do |t|
    t.bigint "appointment_id", null: false
    t.text "body"
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "customer_profile_id", null: false
    t.bigint "employee_membership_id"
    t.datetime "follow_up_at"
    t.string "note_type", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id", "note_type"], name: "idx_booking_notes_appointment_type"
    t.index ["appointment_id"], name: "index_booking_notes_on_appointment_id"
    t.index ["business_id", "customer_profile_id", "created_at"], name: "idx_booking_notes_business_customer_created"
    t.index ["business_id", "follow_up_at"], name: "idx_booking_notes_follow_up", where: "(follow_up_at IS NOT NULL)"
    t.index ["business_id"], name: "index_booking_notes_on_business_id"
    t.index ["created_by_id"], name: "index_booking_notes_on_created_by_id"
    t.index ["customer_profile_id"], name: "index_booking_notes_on_customer_profile_id"
    t.index ["employee_membership_id"], name: "index_booking_notes_on_employee_membership_id"
  end

  create_table "branches", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address"
    t.string "address_details"
    t.bigint "business_id", null: false
    t.string "city"
    t.string "country", default: "Argentina"
    t.datetime "created_at", null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "name", null: false
    t.string "neighborhood"
    t.string "phone"
    t.string "postal_code"
    t.string "province"
    t.datetime "updated_at", null: false
    t.index ["business_id", "name"], name: "index_branches_on_business_id_and_name", unique: true
    t.index ["business_id"], name: "index_branches_on_business_id"
  end

  create_table "businesses", force: :cascade do |t|
    t.string "address"
    t.string "address_details"
    t.string "arrival_mode", default: "continuous", null: false
    t.jsonb "arrival_times", default: {}, null: false
    t.boolean "billing_enabled", default: true, null: false
    t.string "business_kind", default: "business", null: false
    t.integer "cancellation_notice_hours", default: 12, null: false
    t.string "city"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.string "custom_domain"
    t.boolean "custom_domain_enabled", default: false, null: false
    t.integer "customer_profiles_count", default: 0, null: false
    t.datetime "disabled_at"
    t.boolean "email_booking_cancelled", default: false, null: false
    t.boolean "email_campaign_summary", default: false, null: false
    t.boolean "email_daily_digest", default: false, null: false
    t.boolean "email_daily_sales_digest", default: false, null: false
    t.boolean "email_new_booking", default: false, null: false
    t.boolean "email_new_deposit_proof", default: false, null: false
    t.boolean "email_new_waitlist_entry", default: false, null: false
    t.boolean "email_weekly_digest", default: false, null: false
    t.boolean "email_weekly_sales_digest", default: false, null: false
    t.integer "employee_memberships_count", default: 0, null: false
    t.string "industry", default: "dog_grooming", null: false
    t.string "instagram_url"
    t.decimal "latitude", precision: 10, scale: 7
    t.string "legal_name"
    t.decimal "longitude", precision: 10, scale: 7
    t.string "mobile_area_code", default: "11", null: false
    t.string "name", null: false
    t.string "neighborhood"
    t.datetime "onboarding_completed_at"
    t.bigint "owner_id", null: false
    t.string "phone"
    t.jsonb "preferences", default: {}, null: false
    t.string "province"
    t.string "public_accent_color"
    t.text "public_category_custom_html"
    t.text "public_custom_css"
    t.text "public_custom_html"
    t.string "public_email"
    t.string "public_font_style"
    t.string "public_headline"
    t.boolean "public_landing_enabled", default: false, null: false
    t.string "public_primary_color"
    t.string "public_secondary_color"
    t.boolean "public_show_deposit_amounts", default: true, null: false
    t.boolean "public_show_gallery", default: true, null: false
    t.boolean "public_show_gap_promos", default: true, null: false
    t.boolean "public_show_location", default: true, null: false
    t.boolean "public_show_next_slots", default: true, null: false
    t.boolean "public_show_prices", default: true, null: false
    t.boolean "public_show_professionals", default: true, null: false
    t.boolean "public_show_waitlist", default: true, null: false
    t.string "public_site_mode", default: "booking_link", null: false
    t.string "public_template", default: "clean_clinic", null: false
    t.string "referral_reward_description"
    t.boolean "referrals_enabled", default: false, null: false
    t.integer "rescheduling_notice_hours", default: 24, null: false
    t.bigint "service_catalog_category_id"
    t.integer "services_count", default: 0, null: false
    t.string "setup_status", default: "not_started", null: false
    t.integer "simultaneous_capacity"
    t.string "slogan"
    t.string "slug", null: false
    t.datetime "trial_ends_at", null: false
    t.datetime "trial_started_at", null: false
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index "lower((slug)::text)", name: "index_businesses_on_lower_slug", unique: true
    t.index ["billing_enabled"], name: "index_businesses_on_billing_enabled"
    t.index ["custom_domain", "custom_domain_enabled"], name: "index_businesses_on_custom_domain_and_enabled"
    t.index ["custom_domain"], name: "index_businesses_on_custom_domain", unique: true, where: "(custom_domain IS NOT NULL)"
    t.index ["industry"], name: "index_businesses_on_industry"
    t.index ["latitude", "longitude"], name: "index_businesses_on_latitude_and_longitude"
    t.index ["owner_id"], name: "index_businesses_on_owner_id", unique: true
    t.index ["preferences"], name: "index_businesses_on_preferences", using: :gin
    t.index ["public_site_mode"], name: "index_businesses_on_public_site_mode"
    t.index ["public_template"], name: "index_businesses_on_public_template"
    t.index ["service_catalog_category_id"], name: "index_businesses_on_service_catalog_category_id"
    t.check_constraint "arrival_mode::text = ANY (ARRAY['fixed'::character varying::text, 'continuous'::character varying::text])", name: "businesses_valid_arrival_mode"
    t.check_constraint "simultaneous_capacity >= 1 AND simultaneous_capacity <= 10", name: "businesses_valid_capacity"
  end

  create_table "campaign_links", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "business_id", null: false
    t.string "campaign"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "destination_type", default: "public_home", null: false
    t.string "medium"
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.bigint "service_id"
    t.string "slug", null: false
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "source", "active"], name: "idx_campaign_links_business_source"
    t.index ["business_id"], name: "index_campaign_links_on_business_id"
    t.index ["created_by_id"], name: "index_campaign_links_on_created_by_id"
    t.index ["service_id"], name: "index_campaign_links_on_service_id"
    t.index ["slug"], name: "index_campaign_links_on_slug", unique: true
  end

  create_table "campaign_visits", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "campaign_link_id"
    t.datetime "created_at", null: false
    t.string "ip_hash"
    t.string "referer"
    t.string "session_id"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.datetime "visited_at", null: false
    t.string "visitor_token"
    t.index ["business_id", "visited_at"], name: "idx_campaign_visits_business_visited"
    t.index ["business_id"], name: "index_campaign_visits_on_business_id"
    t.index ["campaign_link_id", "visited_at"], name: "idx_campaign_visits_link_visited"
    t.index ["campaign_link_id"], name: "index_campaign_visits_on_campaign_link_id"
  end

  create_table "client_notes", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_profile_id", null: false
    t.string "note_type", default: "general", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["business_id", "customer_profile_id", "created_at"], name: "idx_on_business_id_customer_profile_id_created_at_9cf73bc527"
    t.index ["business_id"], name: "index_client_notes_on_business_id"
    t.index ["customer_profile_id"], name: "index_client_notes_on_customer_profile_id"
    t.index ["user_id"], name: "index_client_notes_on_user_id"
  end

  create_table "commercial_calendar_events", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "category", null: false
    t.string "country", default: "AR", null: false
    t.datetime "created_at", null: false
    t.date "event_date", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["country", "event_date", "active"], name: "idx_commercial_calendar_country_date"
  end

  create_table "content_templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "body", null: false
    t.bigint "business_id"
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "key"], name: "idx_content_templates_business_key", unique: true
    t.index ["business_id"], name: "index_content_templates_on_business_id"
  end

  create_table "customer_packs", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_profile_id", null: false
    t.datetime "expires_at"
    t.text "notes"
    t.datetime "purchased_at", null: false
    t.integer "remaining_sessions", null: false
    t.bigint "service_pack_id", null: false
    t.string "status", default: "active", null: false
    t.integer "total_sessions", null: false
    t.datetime "updated_at", null: false
    t.integer "used_sessions", default: 0, null: false
    t.index ["business_id", "status", "remaining_sessions"], name: "idx_customer_packs_business_status_remaining"
    t.index ["business_id"], name: "index_customer_packs_on_business_id"
    t.index ["customer_profile_id", "status"], name: "idx_customer_packs_customer_status"
    t.index ["customer_profile_id"], name: "index_customer_packs_on_customer_profile_id"
    t.index ["service_pack_id"], name: "index_customer_packs_on_service_pack_id"
  end

  create_table "customer_profiles", force: :cascade do |t|
    t.date "birth_date"
    t.datetime "blocked_at"
    t.text "blocked_reason"
    t.bigint "business_id", null: false
    t.integer "consecutive_late_cancellations_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email"
    t.string "first_name"
    t.string "gender"
    t.text "internal_notes"
    t.datetime "last_late_cancellation_at"
    t.string "last_name"
    t.datetime "last_no_show_at"
    t.string "name"
    t.integer "no_show_count", default: 0, null: false
    t.string "normalized_email"
    t.string "normalized_phone"
    t.string "phone"
    t.integer "total_cancellations_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "deleted_at"], name: "index_customer_profiles_on_business_id_and_deleted_at"
    t.index ["business_id", "last_name", "first_name"], name: "index_customer_profiles_on_business_and_name_parts"
    t.index ["business_id", "normalized_email"], name: "idx_customer_profiles_business_email"
    t.index ["business_id", "normalized_phone"], name: "index_customer_profiles_on_business_id_and_normalized_phone", unique: true
    t.index ["business_id"], name: "index_customer_profiles_on_business_id"
  end

  create_table "customer_reminders", force: :cascade do |t|
    t.bigint "appointment_id"
    t.bigint "assigned_to_id"
    t.text "body", null: false
    t.bigint "business_id", null: false
    t.datetime "completed_at"
    t.bigint "completed_by_id"
    t.datetime "created_at", null: false
    t.bigint "customer_profile_id", null: false
    t.datetime "dismissed_at"
    t.datetime "remind_at", null: false
    t.string "reminder_type", default: "manual", null: false
    t.bigint "service_id"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_customer_reminders_on_appointment_id"
    t.index ["assigned_to_id"], name: "index_customer_reminders_on_assigned_to_id"
    t.index ["business_id", "customer_profile_id", "service_id", "reminder_type", "status"], name: "idx_customer_reminders_dedupe"
    t.index ["business_id", "status", "remind_at"], name: "idx_on_business_id_status_remind_at_ce81325a08"
    t.index ["business_id"], name: "index_customer_reminders_on_business_id"
    t.index ["completed_by_id"], name: "index_customer_reminders_on_completed_by_id"
    t.index ["customer_profile_id"], name: "index_customer_reminders_on_customer_profile_id"
    t.index ["service_id"], name: "index_customer_reminders_on_service_id"
  end

  create_table "dynamic_pricing_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "center_id", null: false
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.decimal "discount_percentage", precision: 5, scale: 2, null: false
    t.time "end_time", null: false
    t.time "start_time", null: false
    t.datetime "updated_at", null: false
    t.index ["center_id", "day_of_week", "active"], name: "idx_dynamic_pricing_lookup"
    t.index ["center_id"], name: "index_dynamic_pricing_rules_on_center_id"
  end

  create_table "email_delivery_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "business_id"
    t.datetime "created_at", null: false
    t.string "mailer", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "provider", default: "resend", null: false
    t.string "provider_message_id"
    t.string "recipient", null: false
    t.datetime "sent_at"
    t.string "status", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "created_at"], name: "idx_email_delivery_logs_business_created"
    t.index ["business_id"], name: "index_email_delivery_logs_on_business_id"
    t.index ["mailer", "action", "status"], name: "idx_email_delivery_logs_mailer_status"
  end

  create_table "employee_availability_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.time "break_end_time"
    t.time "break_start_time"
    t.datetime "created_at", null: false
    t.bigint "employee_membership_id", null: false
    t.time "end_time"
    t.boolean "inherits_business_hours", default: true, null: false
    t.time "start_time"
    t.datetime "updated_at", null: false
    t.integer "weekday", null: false
    t.index ["employee_membership_id", "weekday"], name: "idx_employee_availability_weekday", unique: true
    t.index ["employee_membership_id"], name: "index_employee_availability_rules_on_employee_membership_id"
  end

  create_table "employee_memberships", force: :cascade do |t|
    t.string "additional_phone"
    t.datetime "archived_at"
    t.bigint "branch_id"
    t.bigint "business_id", null: false
    t.string "calendar_color"
    t.boolean "can_receive_appointments", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "first_name"
    t.datetime "invitation_accepted_at"
    t.datetime "invitation_expires_at"
    t.datetime "invitation_sent_at"
    t.string "invitation_token_digest"
    t.bigint "invited_by_id"
    t.string "last_name"
    t.string "name", null: false
    t.jsonb "permissions", default: {}, null: false
    t.string "phone"
    t.integer "sort_order", default: 0, null: false
    t.string "specialty"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["branch_id"], name: "index_employee_memberships_on_branch_id"
    t.index ["business_id", "archived_at"], name: "index_employee_memberships_on_business_id_and_archived_at"
    t.index ["business_id", "email_address"], name: "index_employee_memberships_on_business_id_and_email_address", unique: true
    t.index ["business_id", "sort_order"], name: "index_employee_memberships_on_business_id_and_sort_order"
    t.index ["business_id", "status", "archived_at", "can_receive_appointments"], name: "idx_employee_memberships_on_booking_enabled"
    t.index ["business_id", "status"], name: "index_employee_memberships_on_business_id_and_status"
    t.index ["business_id"], name: "index_employee_memberships_on_business_id"
    t.index ["invitation_token_digest"], name: "index_employee_memberships_on_invitation_token_digest"
    t.index ["invited_by_id"], name: "index_employee_memberships_on_invited_by_id"
    t.index ["user_id"], name: "index_employee_memberships_on_user_id"
  end

  create_table "extras", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "price_cents", default: 0, null: false
    t.boolean "public_visible", default: false, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_extras_on_business_id"
  end

  create_table "gift_cards", force: :cascade do |t|
    t.integer "amount_cents"
    t.bigint "business_id", null: false
    t.string "buyer_name"
    t.string "buyer_phone_e164"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.datetime "expires_at"
    t.text "message"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "purchased_at"
    t.string "recipient_name"
    t.string "recipient_phone_e164"
    t.datetime "redeemed_at"
    t.bigint "redeemed_booking_id"
    t.bigint "service_id"
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "code"], name: "idx_gift_cards_business_code", unique: true
    t.index ["business_id", "status", "created_at"], name: "idx_gift_cards_business_status_created"
    t.index ["business_id"], name: "index_gift_cards_on_business_id"
    t.index ["created_by_id"], name: "index_gift_cards_on_created_by_id"
    t.index ["redeemed_booking_id"], name: "index_gift_cards_on_redeemed_booking_id"
    t.index ["service_id"], name: "index_gift_cards_on_service_id"
  end

  create_table "holidays", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.boolean "closed", default: true, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "date"], name: "index_holidays_on_business_id_and_date", unique: true
    t.index ["business_id"], name: "index_holidays_on_business_id"
  end

  create_table "mercado_pago_connections", force: :cascade do |t|
    t.text "access_token_ciphertext"
    t.bigint "business_id", null: false
    t.datetime "connected_at"
    t.datetime "created_at", null: false
    t.datetime "disconnected_at"
    t.datetime "expires_at"
    t.string "mercado_pago_email"
    t.string "mercado_pago_nickname"
    t.string "mercado_pago_user_id"
    t.jsonb "metadata", default: {}, null: false
    t.string "public_key"
    t.text "refresh_token_ciphertext"
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_mercado_pago_connections_on_business_id", unique: true
    t.index ["mercado_pago_email"], name: "index_mercado_pago_connections_on_mercado_pago_email"
    t.index ["mercado_pago_user_id"], name: "index_mercado_pago_connections_on_mercado_pago_user_id"
  end

  create_table "notification_deliveries", force: :cascade do |t|
    t.bigint "appointment_id"
    t.bigint "business_id", null: false
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.jsonb "payload", default: {}, null: false
    t.string "provider_message_id"
    t.string "recipient", null: false
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.string "template", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_notification_deliveries_on_appointment_id"
    t.index ["business_id", "channel", "status"], name: "idx_on_business_id_channel_status_422ca00cd8"
    t.index ["business_id"], name: "index_notification_deliveries_on_business_id"
  end

  create_table "pack_sessions", force: :cascade do |t|
    t.bigint "appointment_id"
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.bigint "customer_pack_id", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.datetime "used_at", null: false
    t.index ["business_id"], name: "index_pack_sessions_on_business_id"
    t.index ["created_by_id"], name: "index_pack_sessions_on_created_by_id"
    t.index ["customer_pack_id", "appointment_id"], name: "idx_pack_sessions_unique_appointment", unique: true
    t.index ["customer_pack_id"], name: "index_pack_sessions_on_customer_pack_id"
  end

  create_table "payment_accounts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.text "details", null: false
    t.string "name", null: false
    t.boolean "primary_account", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "idx_payment_accounts_one_primary_per_business", unique: true, where: "(primary_account = true)"
    t.index ["business_id"], name: "index_payment_accounts_on_business_id"
  end

  create_table "pets", force: :cascade do |t|
    t.jsonb "behavioral_alerts", default: [], null: false
    t.date "birth_date"
    t.string "breed"
    t.bigint "business_id", null: false
    t.string "coat_details"
    t.string "coat_type"
    t.datetime "created_at", null: false
    t.bigint "customer_profile_id", null: false
    t.text "grooming_reference_note"
    t.string "name", null: false
    t.text "notes"
    t.string "sex"
    t.datetime "updated_at", null: false
    t.index ["business_id", "customer_profile_id"], name: "index_pets_on_business_id_and_customer_profile_id"
    t.index ["business_id"], name: "index_pets_on_business_id"
    t.index ["customer_profile_id", "name"], name: "index_pets_on_customer_profile_id_and_name"
    t.index ["customer_profile_id"], name: "index_pets_on_customer_profile_id"
  end

  create_table "promotions", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "campaign_link_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "ends_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "promotion_type", null: false
    t.bigint "service_id"
    t.datetime "starts_at", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "status", "starts_at"], name: "idx_promotions_business_status_starts"
    t.index ["business_id"], name: "index_promotions_on_business_id"
    t.index ["campaign_link_id"], name: "index_promotions_on_campaign_link_id"
    t.index ["service_id"], name: "index_promotions_on_service_id"
  end

  create_table "provider_events", force: :cascade do |t|
    t.text "body"
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "read_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["business_id", "created_at"], name: "idx_provider_events_business_created_at"
    t.index ["business_id", "event_type"], name: "index_provider_events_on_business_id_and_event_type"
    t.index ["business_id", "read_at"], name: "index_provider_events_on_business_id_and_read_at"
    t.index ["business_id"], name: "index_provider_events_on_business_id"
    t.index ["user_id"], name: "index_provider_events_on_user_id"
  end

  create_table "referrals", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "referred_customer_id"
    t.string "referred_name"
    t.string "referred_phone_e164"
    t.bigint "referrer_customer_id", null: false
    t.string "reward_description"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "referred_phone_e164"], name: "idx_referrals_business_phone"
    t.index ["business_id", "status", "created_at"], name: "idx_referrals_business_status_created"
    t.index ["business_id"], name: "index_referrals_on_business_id"
    t.index ["referred_customer_id"], name: "index_referrals_on_referred_customer_id"
    t.index ["referrer_customer_id"], name: "index_referrals_on_referrer_customer_id"
  end

  create_table "resource_blocks", force: :cascade do |t|
    t.bigint "bookable_resource_id", null: false
    t.bigint "business_id", null: false
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.datetime "ends_at", null: false
    t.string "reason", default: "maintenance", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bookable_resource_id", "cancelled_at"], name: "idx_resource_blocks_resource_cancelled"
    t.index ["bookable_resource_id", "starts_at", "ends_at"], name: "idx_resource_blocks_resource_range"
    t.index ["bookable_resource_id"], name: "index_resource_blocks_on_bookable_resource_id"
    t.index ["business_id", "starts_at", "ends_at"], name: "idx_resource_blocks_business_range"
    t.index ["business_id"], name: "index_resource_blocks_on_business_id"
    t.index ["created_by_id"], name: "index_resource_blocks_on_created_by_id"
  end

  create_table "sales_campaign_recipients", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.datetime "contacted_at"
    t.bigint "converted_booking_id"
    t.datetime "created_at", null: false
    t.bigint "customer_profile_id", null: false
    t.datetime "last_opened_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "phone_e164", null: false
    t.text "rendered_message"
    t.bigint "sales_campaign_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "status"], name: "idx_sales_campaign_recipients_business_status"
    t.index ["business_id"], name: "index_sales_campaign_recipients_on_business_id"
    t.index ["converted_booking_id"], name: "index_sales_campaign_recipients_on_converted_booking_id"
    t.index ["customer_profile_id"], name: "index_sales_campaign_recipients_on_customer_profile_id"
    t.index ["sales_campaign_id", "customer_profile_id"], name: "idx_sales_campaign_recipients_unique_customer", unique: true
    t.index ["sales_campaign_id"], name: "index_sales_campaign_recipients_on_sales_campaign_id"
  end

  create_table "sales_campaigns", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "campaign_link_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "message_template", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "objective", null: false
    t.bigint "service_id"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "status", "created_at"], name: "idx_sales_campaigns_business_status_created"
    t.index ["business_id"], name: "index_sales_campaigns_on_business_id"
    t.index ["campaign_link_id"], name: "index_sales_campaigns_on_campaign_link_id"
    t.index ["created_by_id"], name: "index_sales_campaigns_on_created_by_id"
    t.index ["service_id"], name: "index_sales_campaigns_on_service_id"
  end

  create_table "sales_opportunities", force: :cascade do |t|
    t.bigint "appointment_id"
    t.text "body"
    t.bigint "business_id", null: false
    t.datetime "contacted_at"
    t.datetime "converted_at"
    t.datetime "created_at", null: false
    t.bigint "customer_profile_id"
    t.datetime "dismissed_at"
    t.datetime "due_at"
    t.bigint "employee_membership_id"
    t.jsonb "metadata", default: {}, null: false
    t.string "opportunity_type", null: false
    t.integer "score", default: 0, null: false
    t.bigint "service_id"
    t.string "status", default: "open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_sales_opportunities_on_appointment_id"
    t.index ["business_id", "customer_profile_id", "service_id", "opportunity_type", "status"], name: "idx_sales_opportunities_dedupe_lookup"
    t.index ["business_id", "opportunity_type", "created_at"], name: "idx_sales_opportunities_business_type_created"
    t.index ["business_id", "status", "score"], name: "idx_sales_opportunities_business_status_score"
    t.index ["business_id"], name: "index_sales_opportunities_on_business_id"
    t.index ["customer_profile_id"], name: "index_sales_opportunities_on_customer_profile_id"
    t.index ["employee_membership_id"], name: "index_sales_opportunities_on_employee_membership_id"
    t.index ["service_id"], name: "index_sales_opportunities_on_service_id"
  end

  create_table "service_availability_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.time "end_time"
    t.bigint "service_id", null: false
    t.time "start_time"
    t.datetime "updated_at", null: false
    t.integer "weekday", null: false
    t.index ["service_id", "weekday"], name: "idx_service_availability_rules_weekday"
    t.index ["service_id"], name: "index_service_availability_rules_on_service_id"
  end

  create_table "service_catalog_categories", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "business_industry", default: "dog_grooming", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active", "sort_order"], name: "idx_service_catalog_categories_active_order"
    t.index ["key"], name: "index_service_catalog_categories_on_key", unique: true
  end

  create_table "service_catalog_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "deposit_amount_cents", default: 0, null: false
    t.text "description", null: false
    t.integer "duration_minutes", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.integer "price_cents", default: 0, null: false
    t.bigint "service_catalog_category_id", null: false
    t.string "service_category", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["service_catalog_category_id", "active", "sort_order"], name: "idx_service_catalog_items_category_active_order"
    t.index ["service_catalog_category_id", "name"], name: "idx_service_catalog_items_category_name", unique: true
    t.index ["service_catalog_category_id"], name: "index_service_catalog_items_on_service_catalog_category_id"
  end

  create_table "service_categories", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.boolean "primary_category", default: false, null: false
    t.bigint "service_catalog_category_id"
    t.string "slug", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "active", "sort_order"], name: "idx_service_categories_business_active_order"
    t.index ["business_id", "slug"], name: "index_service_categories_on_business_id_and_slug", unique: true
    t.index ["business_id"], name: "idx_service_categories_one_primary_per_business", unique: true, where: "(primary_category = true)"
    t.index ["business_id"], name: "index_service_categories_on_business_id"
    t.index ["service_catalog_category_id"], name: "index_service_categories_on_service_catalog_category_id"
  end

  create_table "service_form_questions", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.jsonb "options", default: [], null: false
    t.integer "position", default: 0, null: false
    t.string "question_type", null: false
    t.boolean "required", default: false, null: false
    t.bigint "service_form_id", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_service_form_questions_on_business_id"
    t.index ["service_form_id", "position"], name: "idx_service_form_questions_position"
    t.index ["service_form_id"], name: "index_service_form_questions_on_service_form_id"
  end

  create_table "service_form_responses", force: :cascade do |t|
    t.jsonb "answers", default: {}, null: false
    t.bigint "appointment_id", null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_profile_id", null: false
    t.bigint "service_form_id", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id", "service_form_id"], name: "idx_service_form_responses_appointment_form", unique: true
    t.index ["appointment_id"], name: "index_service_form_responses_on_appointment_id"
    t.index ["business_id"], name: "index_service_form_responses_on_business_id"
    t.index ["customer_profile_id"], name: "index_service_form_responses_on_customer_profile_id"
    t.index ["service_form_id"], name: "index_service_form_responses_on_service_form_id"
  end

  create_table "service_forms", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "service_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "service_id"], name: "idx_service_forms_business_service", unique: true
    t.index ["business_id"], name: "index_service_forms_on_business_id"
    t.index ["service_id"], name: "index_service_forms_on_service_id"
  end

  create_table "service_packs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "price_cents"
    t.bigint "service_id"
    t.integer "sessions_count", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "active"], name: "idx_service_packs_business_active"
    t.index ["business_id"], name: "index_service_packs_on_business_id"
    t.index ["service_id"], name: "index_service_packs_on_service_id"
  end

  create_table "service_professionals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "employee_membership_id", null: false
    t.bigint "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_membership_id"], name: "index_service_professionals_on_employee_membership_id"
    t.index ["service_id", "employee_membership_id"], name: "idx_service_professionals_unique", unique: true
    t.index ["service_id"], name: "index_service_professionals_on_service_id"
  end

  create_table "service_recommendations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "recommended_service_id", null: false
    t.bigint "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recommended_service_id"], name: "index_service_recommendations_on_recommended_service_id"
    t.index ["service_id", "recommended_service_id"], name: "idx_service_recommendations_unique", unique: true
    t.index ["service_id"], name: "index_service_recommendations_on_service_id"
  end

  create_table "service_resources", force: :cascade do |t|
    t.bigint "bookable_resource_id", null: false
    t.datetime "created_at", null: false
    t.integer "quantity_required", default: 1, null: false
    t.bigint "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["bookable_resource_id"], name: "index_service_resources_on_bookable_resource_id"
    t.index ["service_id", "bookable_resource_id"], name: "index_service_resources_on_service_id_and_bookable_resource_id", unique: true
    t.index ["service_id"], name: "index_service_resources_on_service_id"
  end

  create_table "service_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "service_id", null: false
    t.string "tag_type", default: "keyword", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_service_tags_on_name"
    t.index ["service_id", "name", "tag_type"], name: "index_service_tags_on_service_id_and_name_and_tag_type", unique: true
    t.index ["service_id"], name: "index_service_tags_on_service_id"
  end

  create_table "services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "after_care"
    t.datetime "archived_at"
    t.date "availability_ends_on"
    t.date "availability_starts_on"
    t.text "before_care"
    t.bigint "business_id", null: false
    t.string "category", default: "General", null: false
    t.datetime "created_at", null: false
    t.integer "deposit_amount_cents", default: 0, null: false
    t.integer "deposit_payment_deadline_minutes", default: 30, null: false
    t.boolean "deposit_required", default: false, null: false
    t.text "description"
    t.integer "duration_minutes", null: false
    t.text "external_payment_link"
    t.jsonb "faq", default: [], null: false
    t.boolean "follow_up_enabled", default: false, null: false
    t.text "includes"
    t.boolean "limit_availability_by_date", default: false, null: false
    t.string "name", null: false
    t.bigint "payment_account_id"
    t.boolean "popular", default: false, null: false
    t.integer "price_cents", default: 0, null: false
    t.string "professional_selection_mode", default: "optional", null: false
    t.integer "public_start_interval_minutes"
    t.boolean "public_visible", default: true, null: false
    t.integer "recommended_follow_up_days"
    t.bigint "service_catalog_item_id"
    t.bigint "service_category_id"
    t.string "slug", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.boolean "use_advanced_availability", default: false, null: false
    t.string "visibility_mode", default: "public", null: false
    t.index ["business_id", "active"], name: "index_services_on_business_id_and_active"
    t.index ["business_id", "archived_at"], name: "index_services_on_business_id_and_archived_at"
    t.index ["business_id", "category"], name: "index_services_on_business_id_and_category"
    t.index ["business_id", "follow_up_enabled"], name: "idx_services_business_follow_up"
    t.index ["business_id", "professional_selection_mode"], name: "idx_services_business_professional_mode"
    t.index ["business_id", "public_visible", "active"], name: "idx_services_public_visible"
    t.index ["business_id", "slug"], name: "idx_services_business_slug", unique: true
    t.index ["business_id", "sort_order"], name: "index_services_on_business_id_and_sort_order"
    t.index ["business_id", "visibility_mode", "active", "archived_at", "sort_order"], name: "idx_services_public_catalog"
    t.index ["business_id", "visibility_mode"], name: "index_services_on_business_id_and_visibility_mode"
    t.index ["business_id"], name: "index_services_on_business_id"
    t.index ["payment_account_id"], name: "index_services_on_payment_account_id"
    t.index ["service_catalog_item_id"], name: "index_services_on_service_catalog_item_id"
    t.index ["service_category_id"], name: "index_services_on_service_category_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subscription_checkout_payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "ARS", null: false
    t.datetime "expires_at"
    t.string "external_reference", null: false
    t.datetime "failed_at"
    t.text "init_point"
    t.datetime "paid_at"
    t.string "preference_id"
    t.string "provider", default: "mercado_pago", null: false
    t.string "provider_payment_id"
    t.jsonb "raw_payload", default: {}, null: false
    t.text "sandbox_init_point"
    t.string "status", default: "pending", null: false
    t.bigint "subscription_invoice_id", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_subscription_checkout_payments_on_business_id"
    t.index ["external_reference"], name: "index_subscription_checkout_payments_on_external_reference", unique: true
    t.index ["provider_payment_id"], name: "index_subscription_checkout_payments_on_provider_payment_id", unique: true
    t.index ["subscription_invoice_id", "status"], name: "idx_on_subscription_invoice_id_status_e51934847e"
    t.index ["subscription_invoice_id"], name: "idx_on_subscription_invoice_id_fe43402b46"
  end

  create_table "subscription_invoices", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.integer "billing_period_months", default: 1, null: false
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.date "due_on", null: false
    t.text "notes"
    t.datetime "overdue_at"
    t.datetime "paid_at"
    t.date "period_end", null: false
    t.date "period_start", null: false
    t.string "plan_selected", default: "basic", null: false
    t.string "reference_code", null: false
    t.datetime "restricted_at"
    t.string "status", default: "open", null: false
    t.bigint "subscription_id", null: false
    t.datetime "suspended_at"
    t.datetime "updated_at", null: false
    t.index ["business_id", "due_on"], name: "index_subscription_invoices_on_business_id_and_due_on"
    t.index ["business_id", "status"], name: "index_subscription_invoices_on_business_id_and_status"
    t.index ["business_id"], name: "index_subscription_invoices_on_business_id"
    t.index ["reference_code"], name: "index_subscription_invoices_on_reference_code", unique: true
    t.index ["subscription_id", "period_start", "period_end"], name: "idx_subscription_invoices_period"
    t.index ["subscription_id"], name: "index_subscription_invoices_on_subscription_id"
  end

  create_table "subscription_payment_proofs", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.text "rejection_reason"
    t.datetime "replaced_at"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.string "status", default: "pending_review", null: false
    t.bigint "subscription_invoice_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "uploaded_at", null: false
    t.bigint "uploaded_by_id"
    t.index ["business_id", "status"], name: "index_subscription_payment_proofs_on_business_id_and_status"
    t.index ["business_id"], name: "index_subscription_payment_proofs_on_business_id"
    t.index ["reviewed_by_id"], name: "index_subscription_payment_proofs_on_reviewed_by_id"
    t.index ["subscription_invoice_id", "status"], name: "idx_subscription_payment_proofs_invoice_status"
    t.index ["subscription_invoice_id"], name: "index_subscription_payment_proofs_on_subscription_invoice_id"
    t.index ["uploaded_by_id"], name: "index_subscription_payment_proofs_on_uploaded_by_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer "amount_cents", default: 3500000, null: false
    t.integer "billing_period_months", default: 1, null: false
    t.bigint "business_id", null: false
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.date "current_period_end"
    t.date "current_period_start"
    t.datetime "expires_at"
    t.string "external_reference", null: false
    t.date "grace_ends_on"
    t.datetime "last_payment_at"
    t.date "next_due_on"
    t.date "paid_until"
    t.string "payer_email"
    t.string "plan_selected", default: "basic", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "restricted_at"
    t.string "status", default: "trialing", null: false
    t.datetime "subscribed_at"
    t.datetime "suspended_at"
    t.date "trial_ends_on"
    t.date "trial_started_on"
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_subscriptions_on_business_id", unique: true
    t.index ["external_reference"], name: "index_subscriptions_on_external_reference", unique: true
    t.check_constraint "plan_selected::text = ANY (ARRAY['basic'::character varying::text, 'pro'::character varying::text])", name: "subscriptions_valid_plan"
  end

  create_table "super_admin_tasks", force: :cascade do |t|
    t.text "body"
    t.bigint "business_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "due_at"
    t.bigint "record_id"
    t.string "record_type"
    t.string "status", default: "pending", null: false
    t.string "task_type", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "task_type", "record_type", "record_id"], name: "idx_super_admin_tasks_uniqueness"
    t.index ["business_id"], name: "index_super_admin_tasks_on_business_id"
    t.index ["record_type", "record_id"], name: "index_super_admin_tasks_on_record_type_and_record_id"
    t.index ["status", "due_at"], name: "index_super_admin_tasks_on_status_and_due_at"
  end

  create_table "tutorials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "sort_order", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.text "video_url", null: false
    t.index ["created_at"], name: "index_tutorials_on_created_at"
    t.index ["sort_order"], name: "index_tutorials_on_sort_order"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "email_address", null: false
    t.datetime "google_connected_at"
    t.string "google_uid"
    t.string "last_login_provider"
    t.string "name"
    t.string "password_digest"
    t.string "phone"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointment_addons", "appointments"
  add_foreign_key "appointment_addons", "services"
  add_foreign_key "appointment_extras", "appointments"
  add_foreign_key "appointment_extras", "extras"
  add_foreign_key "appointment_payments", "appointments"
  add_foreign_key "appointment_payments", "businesses"
  add_foreign_key "appointments", "bookable_resources"
  add_foreign_key "appointments", "branches"
  add_foreign_key "appointments", "businesses"
  add_foreign_key "appointments", "customer_profiles"
  add_foreign_key "appointments", "employee_memberships"
  add_foreign_key "appointments", "pets", on_delete: :nullify
  add_foreign_key "appointments", "services"
  add_foreign_key "appointments", "users", column: "canceled_by_user_id"
  add_foreign_key "appointments", "users", column: "completed_by_id"
  add_foreign_key "appointments", "users", column: "deposit_reviewed_by_id"
  add_foreign_key "appointments", "users", column: "remaining_balance_paid_by_id"
  add_foreign_key "availability_blocks", "bookable_resources"
  add_foreign_key "availability_blocks", "businesses"
  add_foreign_key "availability_blocks", "employee_memberships"
  add_foreign_key "availability_blocks", "users", column: "created_by_id"
  add_foreign_key "availability_rules", "businesses"
  add_foreign_key "billing_reminders", "businesses"
  add_foreign_key "billing_reminders", "subscription_invoices"
  add_foreign_key "bookable_resources", "branches"
  add_foreign_key "bookable_resources", "businesses"
  add_foreign_key "booking_attachments", "appointments"
  add_foreign_key "booking_attachments", "businesses"
  add_foreign_key "booking_attachments", "customer_profiles"
  add_foreign_key "booking_attachments", "users", column: "uploaded_by_id"
  add_foreign_key "booking_attributions", "appointments"
  add_foreign_key "booking_attributions", "businesses"
  add_foreign_key "booking_attributions", "campaign_links"
  add_foreign_key "booking_intents", "appointments"
  add_foreign_key "booking_intents", "businesses"
  add_foreign_key "booking_intents", "customer_profiles"
  add_foreign_key "booking_intents", "employee_memberships"
  add_foreign_key "booking_intents", "services"
  add_foreign_key "booking_notes", "appointments"
  add_foreign_key "booking_notes", "businesses"
  add_foreign_key "booking_notes", "customer_profiles"
  add_foreign_key "booking_notes", "employee_memberships"
  add_foreign_key "booking_notes", "users", column: "created_by_id"
  add_foreign_key "branches", "businesses"
  add_foreign_key "businesses", "service_catalog_categories"
  add_foreign_key "businesses", "users", column: "owner_id"
  add_foreign_key "campaign_links", "businesses"
  add_foreign_key "campaign_links", "services"
  add_foreign_key "campaign_links", "users", column: "created_by_id"
  add_foreign_key "campaign_visits", "businesses"
  add_foreign_key "campaign_visits", "campaign_links"
  add_foreign_key "client_notes", "businesses"
  add_foreign_key "client_notes", "customer_profiles"
  add_foreign_key "client_notes", "users"
  add_foreign_key "content_templates", "businesses"
  add_foreign_key "customer_packs", "businesses"
  add_foreign_key "customer_packs", "customer_profiles"
  add_foreign_key "customer_packs", "service_packs"
  add_foreign_key "customer_profiles", "businesses"
  add_foreign_key "customer_reminders", "appointments"
  add_foreign_key "customer_reminders", "businesses"
  add_foreign_key "customer_reminders", "customer_profiles"
  add_foreign_key "customer_reminders", "services"
  add_foreign_key "customer_reminders", "users", column: "assigned_to_id"
  add_foreign_key "customer_reminders", "users", column: "completed_by_id"
  add_foreign_key "dynamic_pricing_rules", "businesses", column: "center_id"
  add_foreign_key "email_delivery_logs", "businesses"
  add_foreign_key "employee_availability_rules", "employee_memberships"
  add_foreign_key "employee_memberships", "branches"
  add_foreign_key "employee_memberships", "businesses"
  add_foreign_key "employee_memberships", "users"
  add_foreign_key "employee_memberships", "users", column: "invited_by_id"
  add_foreign_key "extras", "businesses"
  add_foreign_key "gift_cards", "appointments", column: "redeemed_booking_id"
  add_foreign_key "gift_cards", "businesses"
  add_foreign_key "gift_cards", "services"
  add_foreign_key "gift_cards", "users", column: "created_by_id"
  add_foreign_key "holidays", "businesses"
  add_foreign_key "mercado_pago_connections", "businesses"
  add_foreign_key "notification_deliveries", "appointments"
  add_foreign_key "notification_deliveries", "businesses"
  add_foreign_key "pack_sessions", "appointments"
  add_foreign_key "pack_sessions", "businesses"
  add_foreign_key "pack_sessions", "customer_packs"
  add_foreign_key "pack_sessions", "users", column: "created_by_id"
  add_foreign_key "payment_accounts", "businesses"
  add_foreign_key "pets", "businesses"
  add_foreign_key "pets", "customer_profiles"
  add_foreign_key "promotions", "businesses"
  add_foreign_key "promotions", "campaign_links"
  add_foreign_key "promotions", "services"
  add_foreign_key "provider_events", "businesses"
  add_foreign_key "provider_events", "users"
  add_foreign_key "referrals", "businesses"
  add_foreign_key "referrals", "customer_profiles", column: "referred_customer_id"
  add_foreign_key "referrals", "customer_profiles", column: "referrer_customer_id"
  add_foreign_key "resource_blocks", "bookable_resources"
  add_foreign_key "resource_blocks", "businesses"
  add_foreign_key "resource_blocks", "users", column: "created_by_id"
  add_foreign_key "sales_campaign_recipients", "appointments", column: "converted_booking_id"
  add_foreign_key "sales_campaign_recipients", "businesses"
  add_foreign_key "sales_campaign_recipients", "customer_profiles"
  add_foreign_key "sales_campaign_recipients", "sales_campaigns"
  add_foreign_key "sales_campaigns", "businesses"
  add_foreign_key "sales_campaigns", "campaign_links"
  add_foreign_key "sales_campaigns", "services"
  add_foreign_key "sales_campaigns", "users", column: "created_by_id"
  add_foreign_key "sales_opportunities", "appointments"
  add_foreign_key "sales_opportunities", "businesses"
  add_foreign_key "sales_opportunities", "customer_profiles"
  add_foreign_key "sales_opportunities", "employee_memberships"
  add_foreign_key "sales_opportunities", "services"
  add_foreign_key "service_availability_rules", "services"
  add_foreign_key "service_catalog_items", "service_catalog_categories"
  add_foreign_key "service_categories", "businesses"
  add_foreign_key "service_categories", "service_catalog_categories"
  add_foreign_key "service_form_questions", "businesses"
  add_foreign_key "service_form_questions", "service_forms"
  add_foreign_key "service_form_responses", "appointments"
  add_foreign_key "service_form_responses", "businesses"
  add_foreign_key "service_form_responses", "customer_profiles"
  add_foreign_key "service_form_responses", "service_forms"
  add_foreign_key "service_forms", "businesses"
  add_foreign_key "service_forms", "services"
  add_foreign_key "service_packs", "businesses"
  add_foreign_key "service_packs", "services"
  add_foreign_key "service_professionals", "employee_memberships"
  add_foreign_key "service_professionals", "services"
  add_foreign_key "service_recommendations", "services"
  add_foreign_key "service_recommendations", "services", column: "recommended_service_id"
  add_foreign_key "service_resources", "bookable_resources"
  add_foreign_key "service_resources", "services"
  add_foreign_key "service_tags", "services"
  add_foreign_key "services", "businesses"
  add_foreign_key "services", "payment_accounts", on_delete: :nullify
  add_foreign_key "services", "service_catalog_items"
  add_foreign_key "services", "service_categories"
  add_foreign_key "sessions", "users"
  add_foreign_key "subscription_checkout_payments", "businesses"
  add_foreign_key "subscription_checkout_payments", "subscription_invoices"
  add_foreign_key "subscription_invoices", "businesses"
  add_foreign_key "subscription_invoices", "subscriptions"
  add_foreign_key "subscription_payment_proofs", "businesses"
  add_foreign_key "subscription_payment_proofs", "subscription_invoices"
  add_foreign_key "subscription_payment_proofs", "users", column: "reviewed_by_id"
  add_foreign_key "subscription_payment_proofs", "users", column: "uploaded_by_id"
  add_foreign_key "subscriptions", "businesses"
  add_foreign_key "super_admin_tasks", "businesses"
end
