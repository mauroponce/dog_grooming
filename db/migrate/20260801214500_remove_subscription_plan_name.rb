class RemoveSubscriptionPlanName < ActiveRecord::Migration[8.0]
  def up
    remove_column :subscriptions, :plan_name, :string if column_exists?(:subscriptions, :plan_name)
  end

  def down
    add_column :subscriptions, :plan_name, :string, null: false, default: "Suscripción HolaTurno" unless column_exists?(:subscriptions, :plan_name)
  end
end
