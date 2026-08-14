class AddManualDepositReviewFields < ActiveRecord::Migration[8.1]
  def change
    add_column :appointments, :deposit_submitted_at, :datetime
    add_column :appointments, :deposit_reviewed_at, :datetime
    add_column :appointments, :deposit_rejection_reason, :text
    add_column :appointments, :customer_marketing_consent, :boolean, null: false, default: false

    add_column :customer_profiles, :marketing_consent, :boolean, null: false, default: false
  end
end
