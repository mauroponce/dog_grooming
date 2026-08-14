class AddDepositReceiptAnalysisToAppointments < ActiveRecord::Migration[8.0]
  def change
    add_column :appointments, :deposit_receipt_analysis, :jsonb, null: false, default: {}
    add_column :appointments, :deposit_receipt_analyzed_at, :datetime
    add_index :appointments, :deposit_receipt_analysis, using: :gin
  end
end
