class AddPlanSelectedToSubscriptionInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :subscription_invoices, :plan_selected, :string, null: false, default: "basic"
  end
end
