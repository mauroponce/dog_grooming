class AddRealtimeQueryIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :appointments, [ :business_id, :status, :starts_at ], name: "idx_appointments_business_status_starts_at", if_not_exists: true
    add_index :appointments, [ :business_id, :deposit_status, :starts_at ], name: "idx_appointments_business_deposit_status_starts_at", if_not_exists: true
    add_index :provider_events, [ :business_id, :created_at ], name: "idx_provider_events_business_created_at", if_not_exists: true
    add_index :services, [ :business_id, :visibility_mode, :active, :archived_at, :sort_order ], name: "idx_services_public_catalog", if_not_exists: true
  end
end
